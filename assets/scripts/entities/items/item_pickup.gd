extends RigidBody2D 
class_name ItemPickup

@export var item_data: ItemData 

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

@onready var pickup_area: Area2D = $PickupArea 
var can_pick_up: bool = false

# NOWA ZMIENNA: Pamięta, czy gracz stoi aktualnie w pobliżu przedmiotu
var player_in_range: Node2D = null

func _ready() -> void:
	if item_data != null:
		item_data = item_data.duplicate()
		if item_data.item_icon != null:
			sprite.texture = item_data.item_icon
			
	pickup_area.area_entered.connect(_on_area_entered)
	
	# NOWE: Szukamy naszego czujnika podświetlania (InteractableComponent) i podłączamy sygnał!
	for child in get_children():
		if child is InteractableComponent:
			child.interacted.connect(_on_interacted)
			break
	
	set_collision_mask_value(1, false)
	await get_tree().create_timer(0.5).timeout
	set_collision_mask_value(1, true)
	can_pick_up = true
	
	prompt_label.hide() # NOWE: Na starcie ukrywamy napis

# 1. Funkcja obsługująca wchłanianie innych przedmiotów z ziemi (BEZ ZMIAN)
func _on_area_entered(area: Area2D) -> void:
	var other_pickup = area.get_parent()
	if other_pickup is ItemPickup and other_pickup != self:
		if self.is_queued_for_deletion() or other_pickup.is_queued_for_deletion():
			return
		var other_item = other_pickup.item_data
		if item_data.item_id == other_item.item_id and item_data.item_is_stackable:
			var available_space = item_data.item_max_stack_count - item_data.item_stack_count
			if available_space > 0:
				var amount_to_take = min(available_space, other_item.item_stack_count)
				item_data.item_stack_count += amount_to_take
				other_item.item_stack_count -= amount_to_take
				if other_item.item_stack_count <= 0:
					other_pickup.queue_free()

# 2. NOWE: Funkcja wywoływana, gdy Gracz celuje w przedmiot i wciska "Interact" (lub klika myszką)
func _on_interacted(interactor: Node) -> void:
	if not can_pick_up or is_queued_for_deletion():
		return
		
	# Duck Typing: Nieważne czy to gracz, czy NPC. Ważne czy ma metodę get_inventory()!
	if interactor.has_method("get_inventory"):
		var inventory = interactor.get_inventory() 
		
		if inventory != null:
			# Próbujemy dodać przedmiot do ekwipunku postaci
			var leftover = inventory.add_item(item_data)
			
			if leftover == 0:
				# Całość się zmieściła - usuwamy z ziemi
				queue_free()
			else:
				# Plecak jest pełny, reszta zostaje na ziemi
				item_data.item_stack_count = leftover


# Stare metody
#func _on_body_entered(body: Node2D) -> void:
	#if body.is_in_group("Player"):
		#player_in_range = body
		## Upewniamy się, że można podnieść i że przedmiot nie zaraz nie zniknie
		#if can_pick_up and not is_queued_for_deletion():
			#prompt_label.show()
		#return
	#
	#if not can_pick_up or is_queued_for_deletion():
		#return
		#
	## Zamiast sprawdzać grupę, sprawdzamy czy obiekt ma ekwipunek:
	#if body.has_method("get_inventory"):
		#var inventory = body.get_inventory()
		#
		#if inventory != null:
			#var leftover = inventory.add_item(item_data)
			#
			#if leftover == 0:
				#queue_free()
			#else:
				#item_data.item_stack_count = leftover
	 #
#
## Gdy gracz wyjdzie ze strefy -> Chowamy przycisk
#func _on_body_exited(body: Node2D) -> void:
	#if body == player_in_range:
		#player_in_range = null
		#prompt_label.hide()
#
## 4. NOWE: Odczytywanie wciśnięcia klawisza "F" (Interact)
#func _unhandled_input(event: InputEvent) -> void:
	## Sprawdzamy czy wciśnięto przycisk ORAZ czy gracz stoi w pobliżu
	#if event.is_action_pressed("PickUpItem") and player_in_range != null:
		#
		## Sprawdzamy blokadę czasową
		#if not can_pick_up or is_queued_for_deletion():
			#return
			#
		#var inventory = player_in_range.get_node_or_null("Inventory") 
		#
		#if inventory != null:
			#var leftover = inventory.add_item(item_data)
			#
			#if leftover == 0:
				#queue_free()
			#else:
				#item_data.item_stack_count = leftover
