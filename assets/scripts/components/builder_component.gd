extends Node
class_name BuilderComponent

const ROTATION_STEP_DEGREES: float = 90.0
const FULL_CIRCLE_DEGREES: float = 360.0
const GHOST_BLOCKED_COLOR := Color(1.0, 0.0, 0.0, 0.75)
const GHOST_VALID_COLOR := Color(0.0, 1.0, 0.0, 0.75)

@export_category("Builder Settings")
## Rozmiar siatki, do której przyciągany jest obiekt (np. 16 lub 32 piksele). 
## Jeśli ustawisz na 0, obiekt będzie poruszał się płynnie piksel po pikselu.
@export var grid_size: float = 64.0 

## Odległość od gracza, w jakiej pojawia się obiekt, gdy gracz używa pada (zamiast myszki).
@export var build_range: float = 320.0 

# --- ZMIENNE WEWNĘTRZNE SYSTEMU ---
## Przechowuje aktualną scenę (prefab), którą próbujemy postawić (np. skrzynię).
var current_build_scene: PackedScene = null
## Referencja do "ducha" (półprzezroczystego hologramu), który podąża za celownikiem/kursorem.
var ghost_instance: Node2D = null
## Flaga określająca, czy gracz aktualnie znajduje się w trybie budowania.
var is_building: bool = false
## Flaga określająca, czy aktualne miejsce podświetlone przez ducha jest wolne (nie koliduje ze ścianami).
var can_place_here: bool = true
## Przechowuje aktualny obrót obiektu (0, 90, 180, 270)
var current_rotation_degrees: float = 0.0

## Pobiera referencję do rodzica, którym powinien być skrypt gracza (PlayerCharacter).
@onready var player: PlayerCharacter = get_parent()

func _process(_delta: float) -> void:
	if not is_building or not is_instance_valid(ghost_instance):
		return

	var target_pos: Vector2 = Vector2.ZERO

	# --- 1. OBLICZANIE POZYCJI DUCHA ---
	if player.is_using_mouse:
		target_pos = ghost_instance.get_global_mouse_position()
		var max_range: float = build_range 
		if max_range > 0.0 and player.global_position.distance_to(target_pos) > max_range:
			var dir: Vector2 = player.global_position.direction_to(target_pos)
			target_pos = player.global_position + (dir * max_range)
	else:
		if player.aim_controller:
			target_pos = player.aim_controller.virtual_cursor_pos
		else:
			target_pos = player.global_position

	# --- 2. PRZYCIĄGANIE DO ŚRODKA KAFELKA (SNAP TO CENTER) ---
	if grid_size > 0.0:
		var cell_x: float = floor(target_pos.x / grid_size)
		var cell_y: float = floor(target_pos.y / grid_size)
		target_pos = Vector2(
			(cell_x * grid_size) + (grid_size / 2.0),
			(cell_y * grid_size) + (grid_size / 2.0)
		)

	ghost_instance.global_position = target_pos
	_validate_placement()

## Funkcja wywoływana przez gracza, gdy wciśnie przycisk wejścia w tryb budowy.
func start_building(item_data: PlaceableComponent) -> bool:
	if item_data.scene_path == null or item_data.scene_path.is_empty():
		push_error("BuilderComponent: Przedmiot nie ma przypisanej sceny!")
		return false

	var loaded_scene: PackedScene = load(item_data.scene_path) as PackedScene
	if not loaded_scene:
		push_error("BuilderComponent: Nie udało się załadować sceny ze ścieżki: ", item_data.scene_path)
		return false

	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()

	current_build_scene = loaded_scene
	is_building = true
	current_rotation_degrees = 0.0

	if player.aim_controller:
		player.aim_controller.reset_virtual_cursor()

	ghost_instance = current_build_scene.instantiate() as Node2D
	ghost_instance.rotation_degrees = current_rotation_degrees
	_disable_collisions(ghost_instance)
	get_tree().current_scene.add_child(ghost_instance)
	return true

# --- OBRACANIE ---
func rotate_object() -> void:
	if not is_building or not is_instance_valid(ghost_instance):
		return

	current_rotation_degrees += ROTATION_STEP_DEGREES
	if current_rotation_degrees >= FULL_CIRCLE_DEGREES:
		current_rotation_degrees = 0.0

	ghost_instance.rotation_degrees = current_rotation_degrees
	_validate_placement()

func stop_building() -> void:
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	ghost_instance = null
	current_build_scene = null
	is_building = false

## Funkcja wywoływana przez gracza (przyciskiem Ataku), by postawić obiekt.
func try_place_object() -> bool:
	if not can_place_here or current_build_scene == null:
		print("BuilderComponent: Miejsce zablokowane!")
		return false

	var final_instance: Node2D = current_build_scene.instantiate() as Node2D

	# Przekazanie Duszy (ItemInstance) z użyciem create_split_copy(1)
	if final_instance is PlacedObject:
		var hand_item: ItemInstance = player.get_inventory().get_current_item()
		if hand_item != null:
			(final_instance as PlacedObject).saved_item_instance = hand_item.create_split_copy(1)

	final_instance.rotation_degrees = current_rotation_degrees
	player.entity_spawn_requested.emit(final_instance, ghost_instance.global_position)
	print("BuilderComponent: Postawiono obiekt (Obrót: " + str(current_rotation_degrees) + "°)")
	return true

func _validate_placement() -> void:
	can_place_here = true
	var is_blocked: bool = false

	ghost_instance.force_update_transform()

	var area: Area2D = ghost_instance.get_node_or_null("BuildArea") as Area2D
	if area != null:
		var col_shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col_shape != null and col_shape.shape != null:
			var space_state: PhysicsDirectSpaceState2D = ghost_instance.get_world_2d().direct_space_state
			var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			query.shape = col_shape.shape
			query.transform = col_shape.global_transform
			query.collision_mask = area.collision_mask
			query.collide_with_bodies = true
			query.collide_with_areas = true

			var results: Array[Dictionary] = space_state.intersect_shape(query)
			for res in results:
				var collider: Object = res["collider"]
				var current_node: Node = collider as Node
				var should_ignore: bool = false
				while current_node != null:
					if current_node == ghost_instance or current_node is ItemPickup:
						should_ignore = true
						break
					current_node = current_node.get_parent()

				if should_ignore:
					continue
				is_blocked = true
				break
		else:
			for body in area.get_overlapping_bodies():
				var current_node: Node = body
				var should_ignore: bool = false
				while current_node != null:
					if current_node == ghost_instance or current_node is ItemPickup:
						should_ignore = true
						break
					current_node = current_node.get_parent()
				if not should_ignore:
					is_blocked = true
					break

	if is_blocked:
		can_place_here = false
		_update_ghost_color(GHOST_BLOCKED_COLOR)
	else:
		can_place_here = true
		_update_ghost_color(GHOST_VALID_COLOR)

func _update_ghost_color(color: Color) -> void:
	if "modulate" in ghost_instance:
		ghost_instance.modulate = color

func _disable_collisions(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		var parent: Node = node.get_parent()
		if parent == null or parent.name != "BuildArea":
			node.set("disabled", true)

	for child in node.get_children():
		_disable_collisions(child)

	var interactable: Node = node.get_node_or_null("InteractableComponent")
	if interactable != null:
		interactable.process_mode = Node.PROCESS_MODE_DISABLED
