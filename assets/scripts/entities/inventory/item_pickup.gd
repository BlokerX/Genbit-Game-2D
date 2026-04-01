extends RigidBody2D 
class_name ItemPickup

@export var item_data: ItemData 
@onready var sprite: Sprite2D = $Sprite2D

# Pobieramy naszą nową strefę Area2D
@onready var pickup_area: Area2D = $PickupArea 

var can_pick_up: bool = false

func _ready() -> void:
	if item_data != null:
		item_data = item_data.duplicate()
		if item_data.item_icon != null:
			sprite.texture = item_data.item_icon
			
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.area_entered.connect(_on_area_entered)
	
	# NOWE: Wyłączamy fizyczne zderzenia z graczem (Mask 1) na ułamek sekundy!
	# Zakładam, że Twój gracz jest na Warstwie (Layer) 1.
	set_collision_mask_value(1, false)
	
	await get_tree().create_timer(0.5).timeout
	
	# NOWE: Włączamy z powrotem zderzenia, żeby móc popychać przedmiot
	set_collision_mask_value(1, true)
	can_pick_up = true

# 1. Funkcja obsługująca wchłanianie innych przedmiotów z ziemi
# 1. Funkcja obsługująca wchłanianie innych przedmiotów z ziemi
func _on_area_entered(area: Area2D) -> void:
	# Pobieramy rodzica strefy, z którą się zderzyliśmy 
	# (bo to tam znajduje się główny skrypt ItemPickup)
	var other_pickup = area.get_parent()
	
	# Sprawdzamy, czy rodzic to faktycznie przedmiot i czy nie jest to ten sam obiekt
	if other_pickup is ItemPickup and other_pickup != self:
		
		# Ignorujemy, jeśli któryś z przedmiotów już się usuwa
		if self.is_queued_for_deletion() or other_pickup.is_queued_for_deletion():
			return
			
		var other_item = other_pickup.item_data
		
		# Sprawdzamy czy to te same, stackowalne przedmioty
		if item_data.item_id == other_item.item_id and item_data.item_is_stackable:
			
			var available_space = item_data.item_max_stack_count - item_data.item_stack_count
			
			if available_space > 0:
				# Obliczamy ile sztuk możemy wchłonąć
				var amount_to_take = min(available_space, other_item.item_stack_count)
				
				# Wchłaniamy sztuki do nas
				item_data.item_stack_count += amount_to_take
				# Odejmujemy sztuki od drugiego przedmiotu
				other_item.item_stack_count -= amount_to_take
				
				# Jeśli wessaliśmy wszystko z drugiego przedmiotu, niszczymy GO 
				# (usuwamy głównego rodzica, czyli other_pickup, a nie samo area)
				if other_item.item_stack_count <= 0:
					other_pickup.queue_free()

# 2. Funkcja obsługująca podnoszenie przez gracza (pozostaje bez większych zmian)
func _on_body_entered(body: Node2D) -> void:
	if not can_pick_up or is_queued_for_deletion():
		return
		
	if body.is_in_group("Player"):
		var inventory = body.get_node_or_null("Inventory") 
		
		if inventory != null:
			var leftover = inventory.add_item(item_data)
			
			if leftover == 0:
				queue_free()
			else:
				item_data.item_stack_count = leftover
