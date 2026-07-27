class_name GridPanel
extends Control

@export var slot_scene: PackedScene = preload("res://assets/scenes/inventory_slot.tscn") # Tu przeciągasz inventory_slot.tscn

# Automatycznie znajduje pierwszy GridContainer w drzewie tej sceny, niezależnie od jego nazwy
@onready var grid_container: GridContainer = _find_grid_container()

var current_source: Node = null
var ui_slots: Array = []

# Funkcja pomocnicza szukająca GridContainer po typie
func _find_grid_container() -> GridContainer:
	for child in get_children():
		if child is GridContainer:
			return child
		# Szukaj głębiej (np. w Panelu czy MarginContainer)
		var found = _deep_search(child)
		if found:
			return found
	return null

func _deep_search(node: Node) -> GridContainer:
	for child in node.get_children():
		if child is GridContainer:
			return child
		var found = _deep_search(child)
		if found:
			return found
	return null

func open_panel(data_source: Node) -> void:
	current_source = data_source
	
	# Podpinanie sygnałów w zależności od tego, z jakiego skryptu przychodzą dane
	if current_source.has_signal("storage_updated") and not current_source.storage_updated.is_connected(_update_all_slots):
		current_source.storage_updated.connect(_update_all_slots)
	elif current_source.has_signal("inventory_updated") and not current_source.inventory_updated.is_connected(_update_all_slots):
		current_source.inventory_updated.connect(_update_all_slots)
		
	_setup_slots(current_source.slots_amount)
	_update_all_slots()
	show()

func close_panel() -> void:
	# Bezpieczne odpinanie sygnałów przy zamykaniu
	if current_source:
		if current_source.has_signal("storage_updated") and current_source.storage_updated.is_connected(_update_all_slots):
			current_source.storage_updated.disconnect(_update_all_slots)
		elif current_source.has_signal("inventory_updated") and current_source.inventory_updated.is_connected(_update_all_slots):
			current_source.inventory_updated.disconnect(_update_all_slots)
			
	current_source = null
	hide()

func _setup_slots(amount: int) -> void:
	# Czyszczenie starych slotów
	for child in grid_container.get_children():
		child.queue_free()
	ui_slots.clear()
	
	# Generowanie nowych
	for i in range(amount):
		var slot_ui = slot_scene.instantiate()
		grid_container.add_child(slot_ui)
		ui_slots.append(slot_ui)
		
		# Sprawdzamy, dla kogo generujemy te sloty
		if current_source is StorageComponent:
			slot_ui.setup_as_storage_slot(i, current_source)
		else:
			slot_ui.setup_as_player_slot(i, current_source)

func _update_all_slots() -> void:
	if not current_source: return
	for i in range(current_source.slots_amount):
		if ui_slots[i].has_method("update_slot"):
			ui_slots[i].update_slot(current_source.slots[i])
