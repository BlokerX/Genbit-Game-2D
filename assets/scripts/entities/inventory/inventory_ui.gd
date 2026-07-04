extends Node

@export var player : PlayerCharacter
# Zmieniamy Sprite2D na naszą nową klasę InventorySlot:
@onready var slots_ui = $InventorySlotHandle.get_children()

# Referencja do naszego tekstu (przeciągniesz go tu w Inspektorze)
@export var info_label: Label

func _ready() -> void:
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_on_inventory_updated)
		_on_inventory_updated()

func _on_inventory_updated() -> void:
	# 1. Aktualizacja slotów
	for i in range(slots_ui.size()):
		if i < player.inventory.slots.size():
			var slot_data = player.inventory.slots[i]
			
			# Aktualizacja wyglądu slotu
			slots_ui[i].update_slot(slot_data)
			
			# Podświetlenie
			var is_selected = (i == player.inventory.current_slot_index)
			slots_ui[i].set_highlight(is_selected)
		else:
			# Jeśli UI ma więcej slotów niż logika ekwipunku
			slots_ui[i].update_slot(null)
			
	# 2. Aktualizacja okienka z informacjami
	update_info_panel()

func update_info_panel() -> void:
	if info_label == null:
		return
		
	# Pobieramy cały slot, aby mieć dostęp do durability i stack_amount
	var slot = player.inventory.get_current_slot()
	
	if slot != null and not slot.is_empty():
		var item = slot.item_data
		
		# Budujemy tekst
		var text = "Nazwa: " + item.item_name + "\n"
		
		# Ilość w slocie (stack_amount z Twojego SlotData)
		if item.item_is_stackable:
			text += "Ilość: " + str(slot.stack_amount) + " / " + str(item.item_max_stack_count) + "\n"
			
		# Wytrzymałość (current_durability z Twojego SlotData)
		if item.max_durable > 0:
			text += "Wytrzymałość: " + str(slot.current_durability) + " / " + str(item.max_durable) + "\n"
			
		if item.item_description != "":
			text += "\n" + item.item_description
			
		info_label.text = text
		info_label.get_parent().show()
	else:
		# Pusty slot
		info_label.get_parent().hide()
