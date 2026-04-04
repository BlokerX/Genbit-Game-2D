# inventory_ui.gd
extends Node

@export var player : PlayerCharacter
# Zmieniamy Sprite2D na naszą nową klasę InventorySlot:
@onready var slots = $InventorySlotHandle.get_children()

# NOWE: Referencja do naszego tekstu (przeciągniesz go tu w Inspektorze)
@export var info_label: Label

func _ready() -> void:
	player.inventory.inventory_updated.connect(_on_inventory_updated)
	_on_inventory_updated() 

func _on_inventory_updated() -> void:
	# 1. Aktualizacja samych slotów i podświetlenia (Twój dotychczasowy kod)
	for i in range(slots.size()):
		var is_selected = (i == player.inventory.current_item_index)
		slots[i].set_highlight(is_selected)
		
		if i < player.inventory.items.size():
			slots[i].update_slot(player.inventory.items[i])
		else:
			slots[i].update_slot(null)
			
	# 2. NOWE: Aktualizacja okienka z informacjami o aktywnym przedmiocie
	update_info_panel()

func update_info_panel() -> void:
	# Upewniamy się, że przypisałeś Label w inspektorze
	if info_label == null:
		return
		
	var current_item = player.inventory.get_current_item()
	
	if current_item != null:
		# Budujemy tekst do wyświetlenia linijka po linijce
		var text = "Nazwa: " + current_item.item_name + "\n"
		
		# Dodajemy stack, jeśli przedmiot się stackuje
		if current_item.item_is_stackable:
			text += "Ilość: " + str(current_item.item_stack_count) + " / " + str(current_item.item_max_stack_count) + "\n"
			
		# Dodajemy wytrzymałość, jeśli przedmiot się psuje
		if current_item.max_durable > 0:
			text += "Wytrzymałość: " + str(current_item.durable) + " / " + str(current_item.max_durable) + "\n"
			
		# Dodajemy opis, jeśli istnieje
		if current_item.item_description != "":
			text += "\n" + current_item.item_description
			
		info_label.text = text
		info_label.get_parent().show() # Pokazuje cały PanelContainer
	else:
		# Jeśli slot jest pusty, ukrywamy okienko (lub piszemy "Pusty slot")
		info_label.get_parent().hide()
