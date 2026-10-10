class_name UIController extends CanvasLayer

const INPUT_TOGGLE_INVENTORY = "ToggleInventory"
const INPUT_TOGGLE_CRAFTING = "ToggleCrafting"
const INPUT_TOGGLE_MAP = "ToggleMap"
const INPUT_GAME_PAUSE = "Game_Pause"

const EquipmentInventoryUIType = preload("res://assets/scripts/ui/equipment_inventory_ui.gd")
const InventorySlotInteractorType = preload("res://assets/scripts/ui/inventory_slot_interactor.gd")

@export_category("Główne Okna")
@export var main_inventory_window: Control # Cały kontener z tłem ekwipunku

@export_category("Panele Siatek")
@export var chest_panel: GridPanel
@export var player_panel: GridPanel
@export var backpack_panel: GridPanel

@export_category("Inne UI")
@export var hotbar_panel: Control
@export var cursor_item_rect: TextureRect
@export var cursor_amount_label: Label
@export var crafting_ui: Control
@export var minimap_ui: Minimap
@export var quest_log_ui: QuestLogUI
@export var equipment_inventory_ui: EquipmentInventoryUIType

@export_category("Gamepad UI")
## Szybkość poruszania kursorem myszy za pomocą lewej gałki
@export var gamepad_cursor_speed: float = 700.0

# Zmienna na ekwipunek gracza - znajdziemy ją automatycznie!
var player_inventory: Inventory = null
var _player_ref: Node2D = null
var _slot_interactor: InventorySlotInteractorType

var item_in_hand: ItemInstance:
	get:
		return _slot_interactor.held_item if _slot_interactor else null
	set(value):
		if _slot_interactor:
			_slot_interactor.held_item = value
var current_open_chest: Node = null

var is_player_inventory_open: bool = false
var is_crafting_open: bool = false
var is_map_open: bool = false

# --- NOWOŚĆ: Liczniki do auto-wyrzucania przedmiotów ---
var _drop_hold_time: float = 0.0
var _drop_tick_time: float = 0.0

func _ready() -> void:
	# Automatycznie szukamy gracza w scenie po grupie "player"
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		_player_ref = player
		player_inventory = player.get_node_or_null("Inventory")
		
	if not player_inventory:
		push_error("UIController nie mógł znaleźć ekwipunku gracza!")
		return

	_slot_interactor = InventorySlotInteractorType.new()
	_slot_interactor.initialize(player_inventory)
	_slot_interactor.held_item_changed.connect(_update_cursor_visuals)
		
	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_on_storage_closed)
	EventBus.slot_clicked.connect(_slot_interactor.handle_slot_clicked)
	EventBus.open_fullscreen_menu.connect(_on_open_fullscreen_menu)
	if not quest_log_ui:
		push_error("UIController nie ma przypisanego dziennika zadań.")
		return
	
	EventBus.player_died.connect(_close_all_ui)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	
	_update_cursor_visuals()

	if crafting_ui:
		crafting_ui.hide()
		
	# Ukrywamy główne tło ekwipunku i panel zbroi na starcie
	if main_inventory_window:
		main_inventory_window.hide()
	_set_equipment_ui_visible(false)

	if equipment_inventory_ui:
		equipment_inventory_ui.initialize(player_inventory)
	else:
		push_error("UIController nie ma przypisanego EquipmentInventoryUI.")

func _process(delta: float) -> void:
	if DialogueManager.is_active: return
	
	if current_open_chest != null and is_instance_valid(_player_ref):
		var physical_chest = current_open_chest.get_parent()
		if is_instance_valid(physical_chest) and physical_chest is Node2D:
			if _player_ref.global_position.distance_to(physical_chest.global_position) > 150.0:
				_close_all_ui()
	
	if is_any_ui_open():
		var move_dir = Input.get_vector("Left", "Right", "Up", "Down")
		if move_dir != Vector2.ZERO:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner: focus_owner.release_focus()
			
			var current_pos = get_viewport().get_mouse_position()
			var new_pos = current_pos + (move_dir * gamepad_cursor_speed * delta)
			
			var screen_size = get_viewport().get_visible_rect().size
			new_pos.x = clamp(new_pos.x, 0, screen_size.x)
			new_pos.y = clamp(new_pos.y, 0, screen_size.y)
			
			get_viewport().warp_mouse(new_pos)
			
			var motion_event = InputEventMouseMotion.new()
			motion_event.global_position = new_pos
			motion_event.position = new_pos
			Input.parse_input_event(motion_event)
			
	if Input.is_action_pressed("DropItem") and not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
		_drop_hold_time += delta
		if _drop_hold_time > 0.4:
			_drop_tick_time += delta
			if _drop_tick_time > 0.1:
				_try_drop_hovered_slot(false)
				_drop_tick_time = 0.0 
	else:
		_drop_hold_time = 0.0
		_drop_tick_time = 0.0
			
	if item_in_hand != null:
		cursor_item_rect.global_position = get_viewport().get_mouse_position() - (cursor_item_rect.size / 2.0)


func toggle_player_inventory() -> void:
	if is_player_inventory_open:
		_close_all_ui()
	else:
		_close_all_ui()
		is_player_inventory_open = true
		EventBus.set_menu_state(EventBus.MENU_INVENTORY, true)
		
		# Pokazujemy główny kontener (tło)
		if main_inventory_window:
			main_inventory_window.show()
			
		player_panel.open_panel(player_inventory)
		_set_equipment_ui_visible(true)
		
		if hotbar_panel: hotbar_panel.hide()

func toggle_crafting_ui() -> void:
	if is_crafting_open:
		_close_all_ui()
	else:
		_close_all_ui() 
		get_tree().paused = true
		is_crafting_open = true
		EventBus.set_menu_state(EventBus.MENU_CRAFTING, true)
		if crafting_ui: crafting_ui.show()
		if hotbar_panel: hotbar_panel.show()

func toggle_map_ui() -> void:
	if is_map_open:
		_close_all_ui()
	else:
		_close_all_ui()
		is_map_open = true
		EventBus.set_menu_state(EventBus.MENU_MAP, true)
		if minimap_ui: minimap_ui.toggle_large_map(true)
		if hotbar_panel: hotbar_panel.hide()

func _on_storage_opened(storage_ref: Node) -> void:
	_close_all_ui()
	current_open_chest = storage_ref
	_slot_interactor.open_storage = storage_ref
	if current_open_chest.has_signal("storage_destroyed") and not current_open_chest.storage_destroyed.is_connected(_on_storage_destroyed):
		current_open_chest.storage_destroyed.connect(_on_storage_destroyed)
		
	is_player_inventory_open = true
	EventBus.set_menu_state(EventBus.MENU_STORAGE, true)
	
	# Pokazujemy główny kontener (tło)
	if main_inventory_window:
		main_inventory_window.show()
		
	player_panel.open_panel(player_inventory)
	chest_panel.open_panel(storage_ref)
	_set_equipment_ui_visible(true)
	
	if hotbar_panel: hotbar_panel.hide()

func _on_storage_destroyed() -> void:
	_close_all_ui()

func _on_storage_closed() -> void:
	_close_all_ui()

func _close_all_ui() -> void:
	get_tree().paused = false
	
	if item_in_hand != null and player_inventory != null:
		var remainder = player_inventory.add_instance(item_in_hand)
		if remainder != null: player_inventory.item_dropped.emit(remainder, true) 
		item_in_hand = null
		_update_cursor_visuals()
		
	current_open_chest = null
	_slot_interactor.open_storage = null
	is_player_inventory_open = false
	is_crafting_open = false
	is_map_open = false
	
	# Ukrywamy całkowicie okno główne ekwipunku (razem z tłem!)
	if main_inventory_window:
		main_inventory_window.hide()
	
	if minimap_ui: minimap_ui.toggle_large_map(false)
	player_panel.close_panel()
	_set_equipment_ui_visible(false)
	chest_panel.close_panel()
	if crafting_ui: crafting_ui.hide()
	if hotbar_panel: hotbar_panel.show()
		
	EventBus.set_menu_state(EventBus.MENU_INVENTORY, false, false)
	EventBus.set_menu_state(EventBus.MENU_CRAFTING, false, false)
	EventBus.set_menu_state(EventBus.MENU_MAP, false, false)
	EventBus.set_menu_state(EventBus.MENU_STORAGE, false, true)

func _input(event: InputEvent) -> void:
	if DialogueManager.is_active: return
	
	if event.is_action_pressed(INPUT_GAME_PAUSE):
		if is_any_ui_open():
			_close_all_ui()
			get_viewport().set_input_as_handled()
			
	# --- ULEPSZONE UPUSZCZANIE POZA OKNO (LPM = Wszystko, PPM = 1 Sztuka) ---
	if event is InputEventMouseButton and not event.pressed:
		if item_in_hand != null and is_any_ui_open():
			if not _is_mouse_over_inventory_panels():
				if event.button_index == MOUSE_BUTTON_LEFT:
					_drop_item_from_cursor(true)  # Zrzut całego stacka
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_drop_item_from_cursor(false) # Zrzut tylko jednej sztuki
					get_viewport().set_input_as_handled()
				
	if is_any_ui_open():
		if event.is_action_pressed("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, false)
			get_viewport().set_input_as_handled()
			
		if event.is_action_pressed("RotateBuilding"):
			_simulate_mouse_click(MOUSE_BUTTON_RIGHT, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("RotateBuilding"):
			_simulate_mouse_click(MOUSE_BUTTON_RIGHT, false)
			get_viewport().set_input_as_handled()
			
		if event.is_action_pressed("DropItem"):
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
				_try_drop_hovered_slot(true)
			else:
				_try_drop_hovered_slot(false)
			get_viewport().set_input_as_handled()

func _is_mouse_over_inventory_panels() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 1. Sprawdzamy ramkę samego ekwipunku/skrzyni
	if main_inventory_window and main_inventory_window.visible:
		var panel = main_inventory_window.get_node_or_null("PanelContainer")
		if panel and panel.get_global_rect().has_point(mouse_pos):
			return true
			
	# 2. Sprawdzamy ramkę panelu Craftingu
	if crafting_ui and crafting_ui.visible:
		var panel = crafting_ui.get_node_or_null("BackgroundPanel")
		if panel and panel.get_global_rect().has_point(mouse_pos):
			return true
			
	return false

func _drop_item_from_cursor(drop_all: bool = true) -> void:
	if item_in_hand == null: return
	
	var dropped_instance: ItemInstance
	
	if drop_all:
		dropped_instance = item_in_hand
		item_in_hand = null
	else:
		var hand_amount = item_in_hand.state.get("amount", 1)
		var unique_data = item_in_hand.data.duplicate(true)
		dropped_instance = ItemInstance.new(unique_data, 1)
		dropped_instance.state = item_in_hand.state.duplicate(true)
		dropped_instance.state["amount"] = 1
		
		item_in_hand.state["amount"] = hand_amount - 1
		if item_in_hand.state["amount"] <= 0: item_in_hand = null
			
	_update_cursor_visuals()
	_execute_drop_in_world(dropped_instance)

func _execute_drop_in_world(dropped_instance: ItemInstance) -> void:
	if dropped_instance == null: return
		
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("ItemThrowerComponent"):
		var thrower = player.get_node("ItemThrowerComponent")
		var aim_target = Vector2.ZERO
		if player.has_node("AimController") and player.get_node("AimController").aim_scanner:
			aim_target = player.get_node("AimController").aim_scanner.target_position
		thrower.handle_item_drop(player, dropped_instance, true, true, aim_target)
	else:
		if player_inventory: player_inventory.item_dropped.emit(dropped_instance, true)

func _try_drop_hovered_slot(drop_all: bool) -> void:
	if item_in_hand != null:
		var hand_amount = item_in_hand.state.get("amount", 1)
		var amount_to_drop = hand_amount if drop_all else 1
		var unique_data = item_in_hand.data.duplicate(true)
		var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
		dropped_instance.state = item_in_hand.state.duplicate(true)
		dropped_instance.state["amount"] = amount_to_drop
		item_in_hand.state["amount"] = hand_amount - amount_to_drop
		if item_in_hand.state["amount"] <= 0: item_in_hand = null
		_update_cursor_visuals()
		_execute_drop_in_world(dropped_instance)
		return
		
	var hovered = get_viewport().gui_get_hovered_control()
	var target_slot_ui: InventorySlot = null
	while hovered != null:
		if hovered is InventorySlot:
			target_slot_ui = hovered
			break
		hovered = hovered.get_parent()
		
	if target_slot_ui != null:
		var parent_node = target_slot_ui.parent_reference
		var slot_idx = target_slot_ui.slot_index
			
		var target_slot: SlotData
		if parent_node is StorageComponent: target_slot = parent_node.slots[slot_idx]
		elif parent_node is Inventory: 
			# --- NAPRAWA: Zrozumienie slotów zbroi i plecaka ('Q' na akcesoriach) ---
			if slot_idx <= -10:
				var equip_type = abs(slot_idx + 10)
				target_slot = parent_node.equipment_slots[equip_type]
			else: 
				target_slot = parent_node.slots[slot_idx]
			
		if target_slot and not target_slot.is_empty():
			var slot_amount = target_slot.item.state.get("amount", 1)
			var amount_to_drop = slot_amount if drop_all else 1
			var unique_data = target_slot.item.data.duplicate(true)
			var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
			dropped_instance.state = target_slot.item.state.duplicate(true)
			dropped_instance.state["amount"] = amount_to_drop
			
			target_slot.item.state["amount"] = slot_amount - amount_to_drop
			if target_slot.item.state["amount"] <= 0: target_slot.clear_slot()
				
			if parent_node is StorageComponent: 
				parent_node.storage_updated.emit()
			elif parent_node is Inventory: 
				# ZABEZPIECZENIE: Jeśli wyrzuciliśmy 'Q' coś z plecaka/zbroi, wymuszamy restart pasywek
				if slot_idx <= -10:
					parent_node._recalculate_slots_size()
					parent_node.equipment_updated.emit()
				parent_node.inventory_updated.emit()
				
			_execute_drop_in_world(dropped_instance)

func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active: return
	
	if event.is_action_pressed(INPUT_TOGGLE_INVENTORY):
		if current_open_chest == null: toggle_player_inventory()
		else: _close_all_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_TOGGLE_CRAFTING): 
		toggle_crafting_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_TOGGLE_MAP):
		toggle_map_ui()
		get_viewport().set_input_as_handled()

func _update_cursor_visuals() -> void:
	if item_in_hand != null:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		cursor_item_rect.texture = item_in_hand.data.item_icon
		cursor_item_rect.show()
		var hand_amount = item_in_hand.state.get("amount", 1)
		if hand_amount > 1:
			cursor_amount_label.text = str(hand_amount)
			cursor_amount_label.show()
		else:
			cursor_amount_label.hide()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cursor_item_rect.texture = null
		cursor_item_rect.hide()
		cursor_amount_label.hide()

func is_any_ui_open() -> bool:
	return is_player_inventory_open or current_open_chest != null or is_crafting_open or is_map_open or DialogueManager.is_active

func _simulate_mouse_click(button_idx: int, is_pressed: bool) -> void:
	var hovered = get_viewport().gui_get_hovered_control()
	if hovered == null: return
	var target = hovered
	while target != null:
		if target is BaseButton:
			if is_pressed and button_idx == MOUSE_BUTTON_LEFT: target.emit_signal("pressed")
			return
		if target.has_method("_gui_input"):
			var ev = InputEventMouseButton.new()
			ev.button_index = button_idx
			ev.pressed = is_pressed
			ev.position = target.get_local_mouse_position()
			target._gui_input(ev)
			return
		target = target.get_parent()

func _on_gui_focus_changed(control: Control) -> void:
	if is_any_ui_open() and control != null:
		var center_pos = control.get_global_rect().get_center()
		get_viewport().warp_mouse(center_pos)

func _set_equipment_ui_visible(show_panel: bool) -> void:
	if equipment_inventory_ui:
		equipment_inventory_ui.set_visible(show_panel)

func _on_open_fullscreen_menu(menu_name: String) -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner: focus_owner.release_focus()
	_close_all_ui()
	match menu_name:
		"Crafting": toggle_crafting_ui()
		"Shop": push_warning("UIController: Menu sklepu nie jest zaimplementowane.")
		"Inventory": toggle_player_inventory()
		"Map": toggle_map_ui()
		"QuestLog": quest_log_ui.open_from_menu_request()
		_: push_warning("UIController: Nieznane menu do otwarcia -> " + menu_name)
