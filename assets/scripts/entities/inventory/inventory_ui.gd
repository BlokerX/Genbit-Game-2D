extends Node

@export var player : PlayerCharacter
@export var slot_scene: PackedScene = preload("res://assets/scenes/inventory_slot.tscn")
@onready var hotbar_panel = $HotbarPanel # Używamy węzła zamiast stałej listy dzieci
@export var info_label: Label

var slots_ui: Array = []

func _ready() -> void:
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_on_inventory_updated)
		_on_inventory_updated()

func _on_inventory_updated() -> void:
	if not player or not player.inventory: return
	
	# --- NOWOŚĆ: Bierzemy mniejszą wartość (albo pełny ekwipunek, albo limit Hotbaru) ---
	var displayed_slots_count = min(player.inventory.slots.size(), player.inventory.hotbar_limit)
	
	# Jeśli liczba slotów w UI się nie zgadza z wyświetlaną, przebudowujemy pasek Hotbar!
	if slots_ui.size() != displayed_slots_count:
		for child in hotbar_panel.get_children():
			child.queue_free()
		slots_ui.clear()
		
		# Generujemy tylko tyle slotów, na ile pozwala limit
		for i in range(displayed_slots_count):
			var slot_ui = slot_scene.instantiate()
			hotbar_panel.add_child(slot_ui)
			slot_ui.setup_as_player_slot(i, player.inventory)
			slots_ui.append(slot_ui)
			
	# Aktualizujemy grafiki na bieżących slotach
	for i in range(displayed_slots_count):
		var slot_data = player.inventory.slots[i]
		if slots_ui[i].has_method("update_slot"):
			slots_ui[i].update_slot(slot_data)
		
		var is_selected = (i == player.inventory.current_slot_index)
		if slots_ui[i].has_method("set_highlight"):
			slots_ui[i].set_highlight(is_selected)

	update_info_panel()

func update_info_panel() -> void:
	if info_label == null: return
	var slot = player.inventory.get_current_slot()
	if slot != null and not slot.is_empty():
		var item = slot.item
		var text = "Nazwa: " + item.data.item_name + "\n"
		if item.data.item_is_stackable:
			text += "Ilość: " + str(item.amount) + " / " + str(item.data.item_max_stack_count) + "\n"
		if item.data.max_durable > 0:
			text += "Wytrzymałość: " + str(item.durability) + " / " + str(item.data.max_durable) + "\n"
		if item.data.item_description != "":
			text += "\n" + item.data.item_description
		info_label.text = text
		info_label.get_parent().show()
	else:
		info_label.get_parent().hide()
