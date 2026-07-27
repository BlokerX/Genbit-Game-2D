extends RigidBody2D 
class_name ItemPickup

## Nasza nowa, potężna klasa przechowująca cały stan przedmiotu!
@export var item: ItemInstance

# Przydatne, jeśli kładziesz przedmiot ręcznie w edytorze do testów:
@export var test_item_data: ItemData
@export var test_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var pickup_area: Area2D = $PickupArea 

var can_pick_up: bool = false

func _ready() -> void:
	# FALLBACK: Jeśli postawiliśmy obiekt ręcznie w edytorze bez gotowej instancji, tworzymy ją!
	if item == null and test_item_data != null:
		item = ItemInstance.new(test_item_data, test_amount)
		
	# Odwołujemy się do grafiki poprzez item.data
	if item != null and item.data != null and item.data.item_icon != null:
		sprite.texture = item.data.item_icon
	
	pickup_area.area_entered.connect(_on_area_entered)
	
	# Szukamy naszego czujnika podświetlania (InteractableComponent) i podłączamy sygnały!
	for child in get_children():
		if child is InteractableComponent:
			# Reakcja na kliknięcie/użycie:
			child.collected.connect(_on_interacted)
			
			# Reakcja na namierzenie i odznaczenie celownikiem:
			child.targeted.connect(_on_targeted)
			child.untargeted.connect(_on_untargeted)
			break
	
	set_collision_mask_value(1, false)
	await get_tree().create_timer(0.5).timeout
	
	if not is_instance_valid(self) or is_queued_for_deletion():
		return # Obiekt nie istnieje, przerywamy kod!
		
	set_collision_mask_value(1, true)
	can_pick_up = true
	
	# Pobieramy nazwę poprzez item.data
	if item != null and item.data != null:
		prompt_label.text = item.data.item_name + "\n" + prompt_label.text
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


## Funkcja obsługująca wchłanianie innych przedmiotów z ziemi
func _on_area_entered(area: Area2D) -> void:
	var other_pickup = area.get_parent()
	if other_pickup is ItemPickup and other_pickup != self:
		
		# --- ROZWIĄZANIE RACE CONDITION ---
		# Sprawdzamy ID. Tylko obiekt z WIĘKSZYM ID zajmie się fuzją. 
		if get_instance_id() < other_pickup.get_instance_id():
			return
		
		if self.is_queued_for_deletion() or other_pickup.is_queued_for_deletion():
			return
			
		# Zabezpieczenie przed błędami - czy obie instancje istnieją?
		if item == null or item.data == null or other_pickup.item == null or other_pickup.item.data == null:
			return
		
		# Porównujemy ID i używamy 'item.amount'
		if item.data.item_id == other_pickup.item.data.item_id and item.data.item_is_stackable:
			var available_space = item.data.item_max_stack_count - item.amount
			if available_space > 0:
				var amount_to_take = min(available_space, other_pickup.item.amount)
				
				item.amount += amount_to_take
				other_pickup.item.amount -= amount_to_take
				
				if other_pickup.item.amount <= 0:
					other_pickup.queue_free()

## Funkcja wywoływana, gdy Gracz celuje w przedmiot i wciska "Interact" (lub klika myszką)
func _on_interacted(interactor: Node) -> void:
	if not can_pick_up or is_queued_for_deletion() or item == null or item.data == null: 
		return
		
	# Duck Typing: Nieważne czy to gracz, czy NPC. Ważne czy ma metodę get_inventory()!
	if interactor.has_method("get_inventory"):
		var inventory = interactor.get_inventory() 
		
		if inventory != null:
			# --- UŻYWAMY NASZEJ NOWEJ FUNKCJI ---
			# Przekazujemy całą instancję, zamiast rozbijać ją na item_data i amount
			var leftovers = inventory.add_instance(item)
			
			if leftovers == null:
				# Całość się zmieściła - usuwamy z ziemi
				queue_free()
			else:
				# Plecak jest pełny, aktualizujemy naszą instancję na ziemi by zachowała resztki
				item = leftovers
