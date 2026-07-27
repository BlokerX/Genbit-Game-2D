extends StaticBody2D # Upewnij się, że ten węzeł pokrywa się z Twoją sceną
class_name PlacedObject

@export_category("Drop Settings")
@export var item_to_drop: PlaceableItem 
@export var item_pickup_scene: PackedScene

@onready var interactable_component : InteractableComponent = $InteractableComponent

@export_category("Health Settings")
@export var max_health: int = 30 
var current_health: int

func _ready() -> void:
	current_health = max_health
	# Nasłuchujemy TYLKO sygnału zebrania (klawisz F)
	# Otwieraniem zajmie się storage_component.gd podpięty pod zwykłe "interacted"
	interactable_component.collected.connect(_on_collected)


# --- 1. ZBIERANIE (KLAWISZ F) ---
func _on_collected(_player: Node) -> void:
	print("Gracz bezpiecznie zebrał skrzynię!")
	_break_and_drop()


# --- 2. NISZCZENIE PRZEZ ATAK (LEWY KLIK) ---
func receive_effect(effect: Effect) -> bool:
	if effect is DamageEffect:
		current_health -= effect.damage_amount
		print("Skrzynia dostała: ", effect.damage_amount, " obrażeń! Zostało HP: ", current_health)
		
		# Skrzynia pęka od ciosów
		if current_health <= 0:
			print("Skrzynia zniszczona atakiem!")
			_break_and_drop()
			
		return true
	return false


# --- GŁÓWNA LOGIKA WYRZUCANIA ---
func _break_and_drop() -> void:
	if item_to_drop != null and item_pickup_scene != null:
		var drop = item_pickup_scene.instantiate()
		var drop_instance = ItemInstance.new(item_to_drop, 1)
		drop.set("item", drop_instance)
		drop.global_position = global_position
		get_parent().call_deferred("add_child", drop)
		
		if drop is RigidBody2D:
			var jump_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			drop.apply_central_impulse(jump_dir * 150.0)
			
	queue_free()
