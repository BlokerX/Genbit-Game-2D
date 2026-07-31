extends StaticBody2D
class_name PlacedObject

@export_category("Drop Settings")
@export var item_to_drop: PlaceableItem 
@export var item_pickup_scene: PackedScene

@onready var interactable_component : InteractableComponent = $InteractableComponent

@export_category("Health Settings")
@export var max_health: int = 50 
var current_health: int
var is_broken: bool = false

func _ready() -> void:
	current_health = max_health
	# Nasłuchujemy sygnału zebrania (klawisz F)
	interactable_component.collected.connect(_on_collected)


# --- 1. ZBIERANIE (KLAWISZ F) ---
func _on_collected(_player: Node) -> void:
	print("Gracz bezpiecznie zebrał skrzynię!")
	_break_and_drop(true) # true oznacza: oddaj przedmiot skrzyni


# --- 2. NISZCZENIE PRZEZ ATAK (LEWY KLIK) ---
func receive_effect(effect: Effect) -> bool:
	if effect is DamageEffect and not is_broken:
		current_health -= effect.damage_amount
		print("Skrzynia dostała: ", effect.damage_amount, " obrażeń! Zostało HP: ", current_health)
		
		# Skrzynia pęka od ciosów
		if current_health <= 0:
			is_broken = true # Blokujemy możliwość wielokrotnego zniszczenia
			print("Skrzynia zniszczona atakiem - znika bez zwrotu budynku!")
			_break_and_drop(false) # false oznacza: NIE oddawaj przedmiotu skrzyni
			
		return true
	return false


# --- GŁÓWNA LOGIKA ROZDZIELAJĄCA ---
func _break_and_drop(return_chest_item: bool) -> void:
	# Zamknij interfejs skrzyni, jeśli była aktualnie otwarta przez gracza
	var ui = get_tree().get_first_node_in_group("UI")
	if ui and "current_open_chest" in ui and ui.current_open_chest == self:
		ui._close_all_ui()
		
	# 1. Jeśli gracz zebrał ją kulturalnie (F), wyrzucamy przedmiot skrzyni na ziemię
	if return_chest_item and item_to_drop != null and item_pickup_scene != null:
		var drop = item_pickup_scene.instantiate()
		var drop_instance = ItemInstance.new(item_to_drop, 1)
		drop.set("item", drop_instance)
		drop.global_position = global_position
		get_parent().call_deferred("add_child", drop)
		
		if drop is RigidBody2D:
			var jump_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			drop.apply_central_impulse(jump_dir * 150.0)
			
	# 2. Niezależnie od sposobu zniszczenia, zawartość schowka zawsze wypada na ziemię
	if has_node("StorageComponent"):
		var storage = $StorageComponent as StorageComponent
		if storage and storage.slots:
			for slot_data in storage.slots:
				if slot_data and not slot_data.is_empty() and item_pickup_scene != null:
					var item_drop = item_pickup_scene.instantiate()
					item_drop.set("item", slot_data.item)
					
					var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
					item_drop.global_position = global_position + random_offset
					get_parent().call_deferred("add_child", item_drop)
					
					if item_drop is RigidBody2D:
						var scatter_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
						item_drop.apply_central_impulse(scatter_dir * 120.0)
						
	# Usuwamy obiekt z mapy
	queue_free()
