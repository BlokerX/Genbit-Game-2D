extends StaticBody2D
class_name PlacedObject

@export_category("Drop Settings")
@export var item_to_drop: ItemData

# Pamięć zużycia skrzynki!
var saved_item_instance: ItemInstance = null

@export var item_pickup_scene: PackedScene

@onready var interactable_component : InteractableComponent = $InteractableComponent

@export_category("Health Settings")
@export var max_health: int = 50 
var current_health: int
var is_broken: bool = false

func _ready() -> void:
	current_health = max_health
	# Nasłuchujemy sygnału zebrania (klawisz F)
	if interactable_component:
		interactable_component.collected.connect(_on_collected)

# --- 1. ZBIERANIE (KLAWISZ F) ---
func _on_collected(_player: Node) -> void:
	print("Gracz bezpiecznie zebrał obiekt!")
	_break_and_drop(true) # true oznacza: oddaj przedmiot z powrotem

# --- 2. NISZCZENIE PRZEZ ATAK (LEWY KLIK) ---
func receive_effect(effect: Effect) -> bool:
	if effect is DamageEffect and not is_broken:
		current_health -= effect.damage_amount
		print("Obiekt dostał: ", effect.damage_amount, " obrażeń! Zostało HP: ", current_health)
		
		# Obiekt pęka od ciosów
		if current_health <= 0:
			is_broken = true # Blokujemy możliwość wielokrotnego zniszczenia
			print("Obiekt zniszczony atakiem - znika bez zwrotu!")
			_break_and_drop(false) # false oznacza: NIE oddawaj bazowego przedmiotu
			
		return true
	return false

# --- GŁÓWNA LOGIKA WYRZUCANIA ---
func _break_and_drop(return_base_item: bool) -> void:
	# Jeśli gracz zebrał go kulturalnie (F), wyrzucamy obiekt na ziemię
	if return_base_item and item_pickup_scene != null:
		var drop = item_pickup_scene.instantiate()

		# ZMIANA: Zwracamy DOKŁADNIE to, co postawił gracz (z zapamiętanym stanem)
		if saved_item_instance != null:
			drop.set("item", saved_item_instance)
		elif item_to_drop != null:
			# Fallback: Jeśli skrzynia była postawiona z poziomu edytora (bez gracza)
			var unique_drop_data = item_to_drop.duplicate(true)
			var drop_instance = ItemInstance.new(unique_drop_data, 1)
			drop.set("item", drop_instance)
		else:
			queue_free()
			return
		
		drop.global_position = global_position
		get_parent().call_deferred("add_child", drop)
		
		if drop is RigidBody2D:
			var jump_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			drop.apply_central_impulse(jump_dir * 150.0)
		
	queue_free()
