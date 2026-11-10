extends StaticBody2D
class_name PlacedObject
## Bazowa klasa dla obiektów stawianych na świecie (np. skrzynie, barykady), które można zebrać (F) lub zniszczyć.

const DROP_JUMP_HORIZONTAL_SPREAD: float = 0.5
const DROP_JUMP_IMPULSE_FORCE: float = 150.0

@export_category("Drop Settings")
@export var item_to_drop: ItemData
## Pamięć życia postawionej instancji przedmiotu (zachowuje wytrzymałość i stan po zebraniu).
var saved_item_instance: ItemInstance = null
@export var item_pickup_scene: PackedScene
@onready var interactable_component: InteractableComponent = $InteractableComponent

@export_category("Health Settings")
@export var max_health: int = 50 
var current_health: int
var is_broken: bool = false

func _ready() -> void:
	z_index = GameLayers.ENTITIES
	current_health = max_health
	if interactable_component:
		interactable_component.collected.connect(_on_collected)

# --- 1. ZBIERANIE (KLAWISZ F) ---
func _on_collected(_player: Node) -> void:
	if is_broken:
		return
	is_broken = true
	print("Gracz bezpiecznie zebrał obiekt!")
	_break_and_drop(true) # true oznacza: oddaj przedmiot z powrotem

# --- 2. NISZCZENIE PRZEZ ATAK (LEWY KLIK) ---
func receive_effect(effect: Effect) -> bool:
	if effect is DamageEffect and not is_broken:
		current_health -= effect.damage_amount
		print("Obiekt dostał: ", effect.damage_amount, " obrażeń! Zostało HP: ", current_health)

		if current_health <= 0:
			is_broken = true
			print("Obiekt zniszczony atakiem - znika bez zwrotu!")
			_break_and_drop(false) # false oznacza: NIE oddawaj bazowego przedmiotu
		return true
	return false

# --- GŁÓWNA LOGIKA WYRZUCANIA ---
func _break_and_drop(return_base_item: bool) -> void:
	if return_base_item and item_pickup_scene != null and get_parent() != null:
		var drop: Node2D = item_pickup_scene.instantiate() as Node2D

		if saved_item_instance != null:
			drop.set("item", saved_item_instance)
		elif item_to_drop != null:
			var unique_drop_data: ItemData = item_to_drop.create_unique_copy()
			var drop_instance: ItemInstance = ItemInstance.new(unique_drop_data, 1)
			drop.set("item", drop_instance)
		else:
			queue_free()
			return

		var spawn_pos: Vector2 = global_position
		drop.global_position = spawn_pos
		get_parent().call_deferred("add_child", drop)
		drop.set_deferred("global_position", spawn_pos)

		if drop is RigidBody2D:
			var jump_dir: Vector2 = Vector2(
				randf_range(-DROP_JUMP_HORIZONTAL_SPREAD, DROP_JUMP_HORIZONTAL_SPREAD),
				-1.0
			).normalized()
			# Wywołujemy impuls przez call_deferred, aby ciało było już zarejestrowane w PhysicsServer2D!
			(drop as RigidBody2D).call_deferred("apply_central_impulse", jump_dir * DROP_JUMP_IMPULSE_FORCE)

	queue_free()
