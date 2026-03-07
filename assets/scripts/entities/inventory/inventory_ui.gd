# inventory_ui.gd
extends Control

@export var inventory: Inventory # Przeciągnij tu swój węzeł Inventory z inspektora
@onready var grid: GridContainer = $GridContainer

func _ready() -> void:
	# Podłączamy się pod sygnał z logiki ekwipunku
	inventory.inventory_updated.connect(_on_inventory_updated)
	_on_inventory_updated() # Wywołanie na start, by zaktualizować widok

func _on_inventory_updated() -> void:
	# Pobieramy wszystkie sloty z GridContainer
	var slots = grid.get_children()
	
	for i in range(slots.size()):
		if i < inventory.items.size():
			slots[i].update_slot(inventory.items[i])
		else:
			slots[i].update_slot(null) # Pusty slot
