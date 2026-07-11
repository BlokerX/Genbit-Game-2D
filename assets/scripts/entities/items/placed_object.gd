extends StaticBody2D # Zmień StaticBody2D na typ węzła głównego Twojej skrzyni (np. Node2D, Area2D)
class_name PlacedObject

@export_category("Drop Settings")
## Przedmiot, który wypadnie po zniszczeniu (np. chest.tres)
@export var item_to_drop: PlaceableItem 
## Scena przedmiotu leżącego na ziemi (ItemPickup)
@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")

@export_category("Health Settings")
## Ile uderzeń z miecza wytrzyma obiekt?
@export var max_health: int = 3 
var current_health: int

func _ready() -> void:
	current_health = max_health

# --- 1. ZNISZCZENIE PRZEZ ATAK (MIECZ/BROŃ) ---
# UWAGA: Zmień nazwę tej funkcji na taką, jakiej używają przeciwnicy w Twojej grze
# do przyjmowania obrażeń (np. "take_damage", "apply_damage", "hit")
func take_damage(damage: int = 1) -> void:
	current_health -= damage
	
	# Mały efekt wizualny: po uderzeniu skrzynia mruga na czerwono
	modulate = Color(1.0, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	
	if current_health <= 0:
		_break_and_drop()

# --- 2. (OPCJONALNIE) ZNISZCZENIE PRZEZ INTERAKCJĘ ---
# Jeśli wolisz zbierać obiekty ręką bez bicia ich mieczem (klawiszem 'F')
func interact(_player: Node) -> void:
	_break_and_drop()


# --- GŁÓWNA LOGIKA WYRZUCANIA PRZEDMIOTU ---
func _break_and_drop() -> void:
	if item_to_drop != null and item_pickup_scene != null:
		# Tworzymy instancję leżącego przedmiotu (dokładnie jak przy wyrzucaniu z ekwipunku)
		var drop = item_pickup_scene.instantiate()
		
		# Wstrzykujemy do pickupa dane naszej skrzynki, by na ziemi pojawiła się jej ikonka
		if "item_data" in drop:
			drop.item_data = item_to_drop
		if "amount" in drop:
			drop.amount = 1
			
		# Ustawiamy go idealnie w miejscu zniszczonej budowli
		drop.global_position = global_position
		
		# Bezpiecznie dodajemy wyrzucony przedmiot na mapę
		get_tree().current_scene.call_deferred("add_child", drop)
		
		# Jeśli Twój item_pickup to obiekt fizyczny (RigidBody2D), zróbmy mu mały "podskok" z ziemi!
		if drop is RigidBody2D:
			var jump_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
			drop.apply_central_impulse(jump_dir * 150.0)
			
	# Usuwamy (niszczymy) fizyczną skrzynię z mapy
	queue_free()
