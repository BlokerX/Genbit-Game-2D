extends RigidBody2D 
class_name ItemPickup
## Fizyczna reprezentacja przedmiotu leżącego na ziemi (obsługuje podnoszenie, łączenie stosów i ochronę przed ścianami).

## Domyślny margines bezpieczeństwa (w pikselach) zatrzymujący przedmiot przed ścianą.
const DEFAULT_WALL_SAFE_MARGIN: float = 8.0
## Domyślna maska fizyki dla ścian i twardych przeszkód terenowych.
const DEFAULT_OBSTACLES_COLLISION_MASK: int = 1
const MIN_DISPLAYED_STACK_AMOUNT: int = 1

## Nasza klasa przechowująca cały stan przedmiotu (ilość, wytrzymałość, amunicję).
@export var item: ItemInstance

# Przydatne, jeśli kładziesz przedmiot ręcznie w edytorze do testów
@export var test_item_data: ItemData
@export var test_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var pickup_area: Area2D = $PickupArea 

var can_pick_up: bool = false
var _is_locked: bool = false # Zabezpieczenie przed Race Condition i duplikacją
var _despawn_timer: float = 0.0
var _despawn_limit: float = 0.0 # Cache limitu czasu z GlobalSettings
var _original_prompt_suffix: String = "" # Zapisuje oryginalny dopisek z Labela

func _ready() -> void:
	z_index = GameLayers.LOOT
	# KULOODPORNA FIZYKA U ŹRÓDŁA: Każdy przedmiot w grze (ze skrzyni, spawnera, wroga czy ręki)
	# ma włączoną ciągłą detekcję kolizji (CCD), aby nigdy nie przeniknął przez ścianę!
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

	# Optymalizacja: Pobieramy ustawienie tylko raz na starcie
	if "loot_despawn_time" in GlobalSettings:
		_despawn_limit = float(GlobalSettings.get("loot_despawn_time"))

	if prompt_label != null:
		_original_prompt_suffix = prompt_label.text

	# FALLBACK: Jeśli postawiliśmy obiekt ręcznie w edytorze bez gotowej instancji
	if (item == null or item.data == null) and test_item_data != null:
		var unique_data: ItemData = test_item_data.create_unique_copy()
		item = ItemInstance.new(unique_data, test_amount)

	# Odwołujemy się do grafiki poprzez item.data
	if item != null and item.data != null and item.data.item_icon != null:
		sprite.texture = item.data.item_icon

	pickup_area.area_entered.connect(_on_area_entered)

	# Szukamy naszego czujnika podświetlania (InteractableComponent) i podłączamy sygnały
	for child in get_children():
		if child is InteractableComponent:
			child.collected.connect(_on_interacted)
			child.targeted.connect(_on_targeted)
			child.untargeted.connect(_on_untargeted)
			break

	can_pick_up = true
	_update_prompt()
	if prompt_label != null:
		prompt_label.hide() # Na starcie ukrywamy napis

func _physics_process(delta: float) -> void:
	if _despawn_limit > 0.0:
		_despawn_timer += delta
		if _despawn_timer >= _despawn_limit:
			queue_free()
			print("Przedmiot został usunięty z powodu przekroczenia limitu czasu leżenia.")

## Wspólna metoda pomocnicza (DRY / SOLID): Oblicza bezpieczną pozycję spawnu przedmiotu/obiektu,
## gwarantując, że losowy rozrzut lub offset rzutu nie umieści go wewnątrz ściany ani za nią.
static func calculate_safe_spawn_position(
	origin_pos: Vector2,
	desired_pos: Vector2,
	context_node: Node2D,
	obstacles_mask: int = DEFAULT_OBSTACLES_COLLISION_MASK,
	wall_margin: float = DEFAULT_WALL_SAFE_MARGIN
) -> Vector2:
	if not is_instance_valid(context_node) or not context_node.is_inside_tree():
		return desired_pos
	if origin_pos.is_equal_approx(desired_pos):
		return desired_pos

	var world_2d: World2D = context_node.get_world_2d()
	if not is_instance_valid(world_2d):
		return desired_pos

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin_pos, desired_pos)
	query.collision_mask = obstacles_mask
	if context_node is CollisionObject2D:
		query.exclude = [context_node.get_rid()]

	var result: Dictionary = world_2d.direct_space_state.intersect_ray(query)
	if not result.is_empty() and result.has("position"):
		var hit_pos: Vector2 = result["position"]
		var dir: Vector2 = origin_pos.direction_to(desired_pos)
		var hit_dist: float = origin_pos.distance_to(hit_pos)
		var safe_dist: float = maxf(0.0, hit_dist - wall_margin)
		return origin_pos + (dir * safe_dist)

	return desired_pos

## Aktualizuje etykietę, uwzględniając obecną ilość w stosie
func _update_prompt() -> void:
	if item != null and item.data != null and prompt_label != null:
		var current_amount: int = item.state.get("amount", MIN_DISPLAYED_STACK_AMOUNT)
		var text: String = item.data.item_name

		# Dodajemy licznik tylko jeśli przedmiotów jest więcej niż 1
		if current_amount > MIN_DISPLAYED_STACK_AMOUNT:
			text += " (x" + str(current_amount) + ")"

		if _original_prompt_suffix != "":
			text += "\n" + _original_prompt_suffix

		prompt_label.text = text

# --- FUNKCJE OD ETYKIETY ---
func _on_targeted() -> void:
	if can_pick_up and not is_queued_for_deletion():
		if prompt_label != null:
			prompt_label.show()

func _on_untargeted() -> void:
	if prompt_label != null:
		prompt_label.hide()

## Funkcja obsługująca wchłanianie innych przedmiotów z ziemi
func _on_area_entered(area: Area2D) -> void:
	var other_pickup: Node = area.get_parent()

	if other_pickup is ItemPickup and other_pickup != self:
		var other_item_pickup: ItemPickup = other_pickup as ItemPickup
		# Deterministyczne decydowanie, kto przetwarza fuzję (zapobiega pętli)
		if get_instance_id() < other_item_pickup.get_instance_id():
			return

		# Zabezpieczenie przed usuwanymi oraz zablokowanymi elementami (Race Condition)
		if self.is_queued_for_deletion() or other_item_pickup.is_queued_for_deletion():
			return
		if self._is_locked or other_item_pickup.get("_is_locked") == true:
			return

		if item == null or item.data == null or other_item_pickup.item == null or other_item_pickup.item.data == null:
			return

		if item.can_stack_with(other_item_pickup.item):
			# Korzystamy bezpośrednio z metody eksperckiej ItemInstance.get_max_stack() (DRY / Information Expert)
			var max_stack: int = item.get_max_stack()
			var my_amount: int = item.state.get("amount", 1)
			var other_amount: int = other_item_pickup.item.state.get("amount", 1)
			var available_space: int = max_stack - my_amount

			# WYKONUJEMY BLOKADĘ TYLKO GDY JEST WOLNE MIEJSCE
			if available_space > 0:
				self._is_locked = true
				other_item_pickup.set("_is_locked", true)

				var amount_to_take: int = mini(available_space, other_amount)

				# Aktualizujemy główny pickup
				item.state["amount"] = my_amount + amount_to_take
				if item.has_signal("state_changed"):
					item.state_changed.emit()
				_update_prompt()

				# Aktualizujemy wysysany pickup
				other_item_pickup.item.state["amount"] = other_amount - amount_to_take
				if other_item_pickup.item.has_signal("state_changed"):
					other_item_pickup.item.state_changed.emit()

				if other_item_pickup.item.state["amount"] <= 0:
					other_item_pickup.queue_free()
				else:
					other_item_pickup.call("_update_prompt")
					other_item_pickup.set("_is_locked", false)

				self._is_locked = false

## Funkcja wywoływana, gdy Gracz celuje w przedmiot i wciska "Interact" (lub klika myszką)
func _on_interacted(interactor: Node) -> void:
	if not can_pick_up or is_queued_for_deletion() or _is_locked: 
		return
	if item == null or item.data == null: 
		return

	_is_locked = true 

	# Duck Typing: Nieważne czy to gracz, czy NPC. Ważne czy ma metodę get_inventory()!
	if interactor.has_method("get_inventory"):
		var inventory = interactor.get_inventory() 

		if inventory != null:
			var original_amount: int = item.state.get("amount", 1)
			var leftovers = inventory.add_instance(item)

			if leftovers == null:
				if interactor.has_method("play_item_pickup_feedback"):
					interactor.call("play_item_pickup_feedback")
				queue_free()
			else:
				item = leftovers
				_update_prompt()
				_is_locked = false
				if (
					int(item.state.get("amount", 1)) < original_amount
					and interactor.has_method("play_item_pickup_feedback")
				):
					interactor.call("play_item_pickup_feedback")
		else:
			_is_locked = false 
	else:
		_is_locked = false

## Odbieranie efektów środowiskowych (np. fali uderzeniowej z bomby)
func receive_effect(effect: Effect) -> bool:
	return effect.apply_effect(self)
