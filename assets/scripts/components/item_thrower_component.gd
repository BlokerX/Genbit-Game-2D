extends Node
class_name ItemThrowerComponent

## Sygnał do powiadamiania menedżera poziomu o konieczności umieszczenia węzła na mapie
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

const COLLISION_RESTORE_BUFFER_PX: float = 5.0
const COLLISION_CHECK_INTERVAL_SEC: float = 0.1
const MOUSE_SPREAD_RANGE: float = 0.05
const PAD_SPREAD_RANGE: float = 0.2

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/game_objects/item_pickup.tscn")

@export_group("Throw Settings")
## Dystans o jaki przedmiot musi oddalić się od środka gracza, by włączyć z powrotem kolizję
@export var spawn_offset_radius: float = 45.0 
@export var max_throw_range: float = 150.0
@export var min_throw_force: float = 50.0
@export var pad_throw_force_min: float = 200.0
@export var pad_throw_force_max: float = 300.0
@export var drop_push_force: float = 20.0
@export var throw_force_multiplier: float = 3.0

## Główna funkcja wywoływana, gdy ekwipunek potwierdzi wyrzucenie przedmiotu.
## Opcjonalny parametr custom_origin pozwala przekazać zamrożoną pozycję śmierci gracza.
func handle_item_drop(
	thrower: Node2D,
	dropped_instance: ItemInstance,
	is_thrown: bool,
	is_using_mouse: bool,
	pad_aim_direction: Vector2,
	custom_origin: Vector2 = Vector2.INF
) -> void:
	if item_pickup_scene == null:
		push_error("Błąd: Brak przypisanej sceny item_pickup_scene w ItemThrowerComponent!")
		return
	if not is_instance_valid(thrower):
		return

	var origin_position: Vector2 = custom_origin if custom_origin != Vector2.INF else thrower.global_position
	var drop: Node2D = item_pickup_scene.instantiate() as Node2D

	if "item" in drop:
		drop.item = dropped_instance 

	var drop_direction: Vector2 = Vector2.ZERO
	var drop_force: float = 0.0

	# 1. NAJPIERW OBLICZAMY KIERUNEK
	if is_thrown:
		if is_using_mouse:
			# --- WYRZUT MYSZKĄ ---
			var mouse_global_pos: Vector2 = thrower.get_global_mouse_position()
			var dist_to_mouse: float = origin_position.distance_to(mouse_global_pos)
			var aim_direction: Vector2 = origin_position.direction_to(mouse_global_pos)

			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2.DOWN

			var actual_throw_distance: float = minf(dist_to_mouse, max_throw_range)
			drop_force = maxf(min_throw_force, actual_throw_distance * throw_force_multiplier)

			var spread: Vector2 = Vector2(
				randf_range(-MOUSE_SPREAD_RANGE, MOUSE_SPREAD_RANGE),
				randf_range(-MOUSE_SPREAD_RANGE, MOUSE_SPREAD_RANGE)
			)
			drop_direction = (aim_direction + spread).normalized()
		else:
			# --- WYRZUT PADEM / KLAWIATURĄ ---
			var aim_direction: Vector2 = pad_aim_direction.normalized()
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

			var spread: Vector2 = Vector2(
				randf_range(-PAD_SPREAD_RANGE, PAD_SPREAD_RANGE),
				randf_range(-PAD_SPREAD_RANGE, PAD_SPREAD_RANGE)
			)
			drop_direction = (aim_direction + spread).normalized()
			drop_force = randf_range(pad_throw_force_min, pad_throw_force_max)
	else:
		# --- DELIKATNE UPUSZCZENIE (np. przy śmierci lub przepełnieniu plecaka) ---
		var base_dir: Vector2 = Vector2.ZERO
		if is_using_mouse:
			base_dir = origin_position.direction_to(thrower.get_global_mouse_position())
		else:
			base_dir = pad_aim_direction.normalized()

		if base_dir == Vector2.ZERO or not is_thrown:
			base_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

		drop_direction = base_dir
		drop_force = drop_push_force

	# 2. USTAWIAMY POZYCJĘ PRZED DODANIEM DO DRZEWA SCENY
	drop.global_position = origin_position

	# 3. ZGŁASZAMY SPAWN
	entity_spawn_requested.emit(drop, origin_position)

	# 4. APLIKUJEMY FIZYKĘ W ZGODZIE Z KOLEJKĄ SILNIKA
	if drop is RigidBody2D:
		var rigid_drop: RigidBody2D = drop as RigidBody2D
		rigid_drop.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		if thrower is CollisionObject2D:
			rigid_drop.add_collision_exception_with(thrower)
			_restore_collision_when_clear(rigid_drop, thrower as CollisionObject2D)

		call_deferred("_finalize_dropped_body_physics", rigid_drop, origin_position, drop_direction * drop_force)

## Gwarantuje poprawną pozycję startową i impuls w bezpiecznym momencie poza blokadą PhysicsServer2D.
func _finalize_dropped_body_physics(drop: RigidBody2D, exact_spawn_pos: Vector2, impulse: Vector2) -> void:
	if not is_instance_valid(drop):
		return
	drop.global_position = exact_spawn_pos
	PhysicsServer2D.body_set_state(
		drop.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(drop.global_rotation, exact_spawn_pos)
	)
	drop.apply_central_impulse(impulse)

# =========================================================================
# SYSTEM DYNAMICZNEGO PRZYWRACANIA KOLIZJI (BRAK PRZENIKANIA)
# =========================================================================
func _restore_collision_when_clear(drop: RigidBody2D, thrower: CollisionObject2D) -> void:
	while is_instance_valid(drop) and is_instance_valid(thrower):
		if not drop.is_inside_tree() or not thrower.is_inside_tree():
			break
		var distance: float = drop.global_position.distance_to(thrower.global_position)
		if distance > (spawn_offset_radius + COLLISION_RESTORE_BUFFER_PX):
			drop.remove_collision_exception_with(thrower)
			break
		await get_tree().create_timer(COLLISION_CHECK_INTERVAL_SEC).timeout
