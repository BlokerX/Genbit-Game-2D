extends RigidBody2D 
class_name ItemPickup

@export var item_data: ItemData 

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel

@onready var pickup_area: Area2D = $PickupArea 
var can_pick_up: bool = false

func _ready() -> void:
	if item_data != null:
		item_data = item_data.duplicate()
		if item_data.item_icon != null:
			sprite.texture = item_data.item_icon
			
	pickup_area.area_entered.connect(_on_area_entered)
	
	# Szukamy naszego czujnika podświetlania (InteractableComponent) i podłączamy sygnały!
	for child in get_children():
		if child is InteractableComponent:
			# Reakcja na kliknięcie/użycie:
			child.interacted.connect(_on_interacted)
			
			# Reakcja na namierzenie i odznaczenie celownikiem:
			child.targeted.connect(_on_targeted)
			child.untargeted.connect(_on_untargeted)
			break
	
	set_collision_mask_value(1, false)
	await get_tree().create_timer(0.5).timeout
	set_collision_mask_value(1, true)
	can_pick_up = true
	
	prompt_label.hide() # Na starcie ukrywamy napis


# --- FUNKCJE OD ETYKIETY ---

func _on_targeted() -> void:
	# Pokazujemy etykietę tylko wtedy, gdy przedmiot można już podnieść i nie znika
	if can_pick_up and not is_queued_for_deletion():
		if prompt_label != null:
			prompt_label.show()

func _on_untargeted() -> void:
	# Chowamy etykietę, gdy zjedziemy z niej celownikiem
	if prompt_label != null:
		prompt_label.hide()


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
