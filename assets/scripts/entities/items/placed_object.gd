extends StaticBody2D # Zmień StaticBody2D na typ węzła głównego Twojej skrzyni (np. Node2D, Area2D)
class_name PlacedObject

@export_category("Drop Settings")
## Przedmiot, który wypadnie po zniszczeniu (np. chest.tres)
@export var item_to_drop: PlaceableItem 
## Scena przedmiotu leżącego na ziemi (ItemPickup)
@export var item_pickup_scene: PackedScene

@onready var interactable_component : InteractableComponent = $InteractableComponent

@export_category("Health Settings")
## Ile uderzeń z miecza wytrzyma obiekt?
@export var max_health: int = 3 
var current_health: int

func _ready() -> void:
	current_health = max_health
	interactable_component.interacted.connect(on_interact)

# ---  ZNISZCZENIE PRZEZ INTERAKCJĘ ---
func on_interact(_player: Node) -> void:
	_break_and_drop()


# --- GŁÓWNA LOGIKA WYRZUCANIA PRZEDMIOTU ---
func _break_and_drop() -> void:
	if item_to_drop != null and item_pickup_scene != null:
		# Tworzymy instancję leżącego przedmiotu (dokładnie jak przy wyrzucaniu z ekwipunku)
		var drop = item_pickup_scene.instantiate()
		
		# Pakujemy zdefiniowany przedmiot (z Inspektora) do nowej instancji o ilości 1
		var drop_instance = ItemInstance.new(item_to_drop, 1)
		
		# Bezpiecznie wstrzykujemy wygenerowaną instancję do pickupa na ziemi
		drop.set("item", drop_instance)
			
		# Ustawiamy go idealnie w miejscu zniszczonej budowli
		drop.global_position = global_position
		
		# Bezpiecznie dodajemy wyrzucony przedmiot do tego samego pokoju, w którym była skrzynia
		get_parent().call_deferred("add_child", drop)
		
		# Jeśli Twój item_pickup to obiekt fizyczny (RigidBody2D), zróbmy mu mały "podskok" z ziemi!
		if drop is RigidBody2D:
			var jump_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			drop.apply_central_impulse(jump_dir * 150.0)
			
	# Usuwamy (niszczymy) fizyczną skrzynię z mapy
	queue_free()
