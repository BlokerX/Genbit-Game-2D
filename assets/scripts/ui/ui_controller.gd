class_name UIController
extends CanvasLayer

@export var chest_panel: GridPanel
@export var player_panel: GridPanel

@export var hotbar_panel: Control
@export var cursor_item_rect: TextureRect
@export var cursor_amount_label: Label

# Zmienna na ekwipunek gracza - znajdziemy ją automatycznie!
var player_inventory: Inventory = null

var item_in_hand: ItemInstance = null
var current_open_chest: Node = null
var is_player_inventory_open: bool = false

func _ready() -> void:
	# Automatycznie szukamy gracza w scenie po grupie "player"
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Zakładam, że wewnątrz gracza Twój skrypt inventory.gd ma węzeł o nazwie "Inventory"
		# (Jeśli Twój węzeł nazywa się inaczej, zmień "$Inventory" na odpowiednią ścieżkę)
		player_inventory = player.get_node_or_null("Inventory")
	
	if not player_inventory:
		push_error("UIController nie mógł znaleźć ekwipunku gracza! Upewnij się, że gracz jest w grupie 'player' i posiada węzeł Inventory.")
		return

	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_on_storage_closed)
	EventBus.slot_clicked.connect(_on_slot_clicked)
	
	var slot_handle = find_child("InventorySlotHandle", true, true)
	if slot_handle:
		var index: int = 0
		for child in slot_handle.get_children():
			if child is InventorySlot:
				child.setup_as_player_slot(index, player_inventory)
				index += 1
	else:
		push_warning("Nie znaleziono węzła InventorySlotHandle w interfejsie gracza!")
		
	if slot_handle:
		var index: int = 0
		for child in slot_handle.get_children():
			if child is InventorySlot:
				child.setup_as_player_slot(index, player_inventory)
				index += 1
	else:
		push_warning("Nie znaleziono węzła InventorySlotHandle!")
	
	_update_cursor_visuals()

func _process(_delta: float) -> void:
	if item_in_hand != null:
		# Używamy get_viewport().get_mouse_position() zamiast get_global_mouse_position()
		cursor_item_rect.global_position = get_viewport().get_mouse_position() + Vector2(5, 5)

func toggle_player_inventory() -> void:
	if is_player_inventory_open:
		_close_all_ui()
	else:
		is_player_inventory_open = true
		player_panel.open_panel(player_inventory)
		if hotbar_panel:
			hotbar_panel.hide() # Ukrywa hotbar

func _on_storage_opened(storage_ref: Node) -> void:
	current_open_chest = storage_ref
	is_player_inventory_open = true
	player_panel.open_panel(player_inventory)
	chest_panel.open_panel(storage_ref)
	if hotbar_panel:
		hotbar_panel.hide() # Ukrywa hotbar

func _on_storage_closed() -> void:
	_close_all_ui()

func _close_all_ui() -> void:
	if item_in_hand != null and player_inventory != null:
		var remainder = player_inventory.add_instance(item_in_hand)
		if remainder != null:
			player_inventory.item_dropped.emit(remainder, true) 
		item_in_hand = null
		
	_update_cursor_visuals()
	current_open_chest = null
	is_player_inventory_open = false
	player_panel.close_panel()
	chest_panel.close_panel()
	if hotbar_panel:
		hotbar_panel.show() # Przywraca hotbar

# DODAJEMY NOWĄ FUNKCJĘ _input, KTÓRA JEST PIERWSZA W KOLEJCE:
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Game_Pause"):
		if is_player_inventory_open or current_open_chest != null:
			_close_all_ui()
			get_viewport().set_input_as_handled() # Zjadamy sygnał, Pauza się nie włączy!
	
	# --- WYRZUCANIE PRZEDMIOTU POZA OKNO PRZY PUSZCZENIU MYSZKI ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if item_in_hand != null and is_player_inventory_open:
			# Sprawdzamy, czy kursor myszy znajduje się POZA głównym panelem UI ekwipunku
			if not _is_mouse_over_inventory_panels():
				_drop_item_from_cursor()

# Pomocnicza funkcja sprawdzająca, czy kursor jest nad okienkiem ekwipunku
func _is_mouse_over_inventory_panels() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Sprawdzamy panel gracza
	if player_panel and player_panel.visible:
		if player_panel.get_global_rect().has_point(mouse_pos):
			return true
			
	# Sprawdzamy panel skrzyni (jeśli jest otwarta)
	if chest_panel and chest_panel.visible:
		if chest_panel.get_global_rect().has_point(mouse_pos):
			return true
			
	return false

# Funkcja wyrzucająca trzymany przedmiot na ziemię
func _drop_item_from_cursor() -> void:
	var dropped_instance = item_in_hand
	item_in_hand = null
	_update_cursor_visuals()
	
	# Zlecamy graczowi wyrzucenie przedmiotu przez jego ItemThrowerComponent
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("ItemThrowerComponent"):
		var thrower = player.get_node("ItemThrowerComponent")
		var aim_target = Vector2.ZERO
		if player.has_node("AimController") and player.get_node("AimController").aim_scanner:
			aim_target = player.get_node("AimController").aim_scanner.target_position
			
		thrower.handle_item_drop(player, dropped_instance, true, true, aim_target)
	else:
		# Fallback awaryjny, gdyby komponentu zabrakło
		player_inventory.item_dropped.emit(dropped_instance, true)
		
	print("UIController: Wyrzucono przedmiot poza ramkę interfejsu!")

# ZMIENIAMY _unhandled_input TAK, ŻEBY OTWIERAŁO TYLKO EKWIPUNEK:
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Inventory"):
		if current_open_chest == null:
			toggle_player_inventory()
		else:
			_close_all_ui()
		get_viewport().set_input_as_handled()

# --- LOGIKA MINECRAFTOWA (KLIKNIĘCIA) ---

func _on_slot_clicked(parent_node: Node, slot_index: int, button_index: int) -> void:
	var target_slot: SlotData
	
	if parent_node is StorageComponent:
		target_slot = parent_node.slots[slot_index]
	elif parent_node is Inventory:
		target_slot = parent_node.slots[slot_index]
	else:
		return

	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(target_slot)
	elif button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(target_slot)
	elif button_index == -1: 
		_handle_quick_transfer(parent_node, slot_index)

	_update_cursor_visuals()
	
	if parent_node is StorageComponent:
		parent_node.storage_updated.emit()
	elif parent_node is Inventory:
		parent_node.inventory_updated.emit()

func _handle_left_click(slot: SlotData) -> void:
	if item_in_hand == null:
		if not slot.is_empty():
			item_in_hand = slot.item
			slot.clear_slot()
	else:
		if slot.is_empty():
			slot.item = item_in_hand
			item_in_hand = null
		else:
			if slot.item.data.item_id == item_in_hand.data.item_id and item_in_hand.data.item_is_stackable:
				var available_space = slot.item.data.item_max_stack_count - slot.item.amount
				if available_space > 0:
					var amount_to_add = min(available_space, item_in_hand.amount)
					slot.item.amount += amount_to_add
					item_in_hand.amount -= amount_to_add
					if item_in_hand.amount <= 0:
						item_in_hand = null
			else:
				var temp_item = slot.item
				slot.item = item_in_hand
				item_in_hand = temp_item

func _handle_right_click(slot: SlotData) -> void:
	if item_in_hand == null:
		if not slot.is_empty():
			if slot.item.amount > 1:
				@warning_ignore("integer_division")
				var half_amount = int(slot.item.amount / 2) 
				item_in_hand = ItemInstance.new(slot.item.data, half_amount)
				item_in_hand.durability = slot.item.durability
				slot.item.amount -= half_amount
			else:
				item_in_hand = slot.item
				slot.clear_slot()
	else:
		if slot.is_empty():
			slot.item = ItemInstance.new(item_in_hand.data, 1)
			slot.item.durability = item_in_hand.durability
			item_in_hand.amount -= 1
			if item_in_hand.amount <= 0:
				item_in_hand = null
		elif slot.item.data.item_id == item_in_hand.data.item_id and item_in_hand.data.item_is_stackable:
			if slot.item.amount < slot.item.data.item_max_stack_count:
				slot.item.amount += 1
				item_in_hand.amount -= 1
				if item_in_hand.amount <= 0:
					item_in_hand = null

func _handle_quick_transfer(from_node: Node, slot_index: int) -> void:
	if not current_open_chest or not player_inventory: return 
	
	if from_node is StorageComponent:
		var instance_to_move = from_node.remove_instance(slot_index)
		if instance_to_move != null:
			var remainder = player_inventory.add_instance(instance_to_move)
			if remainder != null:
				from_node.insert_instance(remainder)

	elif from_node is Inventory: 
		var slot_data = from_node.slots[slot_index]
		if not slot_data.is_empty():
			var instance_to_move = slot_data.item 
			slot_data.clear_slot()
			
			var remainder = current_open_chest.insert_instance(instance_to_move)
			if remainder != null:
				player_inventory.add_instance(remainder)

func _update_cursor_visuals() -> void:
	if item_in_hand != null:
		cursor_item_rect.texture = item_in_hand.data.item_icon
		cursor_item_rect.show()
		if item_in_hand.amount > 1:
			cursor_amount_label.text = str(item_in_hand.amount)
			cursor_amount_label.show()
		else:
			cursor_amount_label.hide()
	else:
		cursor_item_rect.texture = null
		cursor_item_rect.hide()
		cursor_amount_label.hide()
