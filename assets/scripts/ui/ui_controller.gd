class_name UIController extends CanvasLayer

const INPUT_TOGGLE_INVENTORY = "ToggleInventory"
const INPUT_TOGGLE_CRAFTING = "ToggleCrafting"
const INPUT_TOGGLE_MAP = "ToggleMap"
const INPUT_GAME_PAUSE = "Game_Pause"

const EquipmentInventoryUIType = preload("res://assets/scripts/ui/equipment_inventory_ui.gd")
const InventorySlotInteractorType = preload("res://assets/scripts/ui/inventory_slot_interactor.gd")
const InventoryCursorControllerType = preload("res://assets/scripts/ui/inventory_cursor_controller.gd")

@export_category("Główne Okna")
@export var main_inventory_window: Control 

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

@export_group("Oprawa dźwiękowa")
@export var map_open_feedback: FeedbackCue = preload("res://assets/data/feedback/map_open.tres")

@export_category("Gamepad UI")
@export var gamepad_cursor_speed: float = 700.0

# --- REFAKTORYZACJA SOLID (Zamiast dziesiątek flag is_open) ---
var _active_menu_name: String = ""
var _ui_panels: Dictionary = {}

var player_inventory: Inventory = null
var _player_ref: Node2D = null

var _slot_interactor: InventorySlotInteractorType
var _cursor_controller: InventoryCursorControllerType

var item_in_hand: ItemInstance:
	get: return _slot_interactor.held_item if _slot_interactor else null
	set(value): if _slot_interactor: _slot_interactor.held_item = value

var current_open_chest: Node = null

# Zmienne dla wyrzucania przedmiotów
var _drop_hold_time: float = 0.0
var _drop_tick_time: float = 0.0
# Zmienna do optymalizacji pada
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_slot_interactor = InventorySlotInteractorType.new()
	_cursor_controller = InventoryCursorControllerType.new()
	
	_validate_player_refs()
	
	_slot_interactor.held_item_changed.connect(_cursor_controller.update_cursor_visuals)
	
	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_close_all_ui)
	EventBus.slot_clicked.connect(_slot_interactor.handle_slot_clicked)
	EventBus.open_fullscreen_menu.connect(_on_open_fullscreen_menu)
	EventBus.player_died.connect(_close_all_ui)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	
	_cursor_controller.update_cursor_visuals()

	# Rejestracja paneli do generycznego systemu (OCP)
	_ui_panels = {
		"Inventory": main_inventory_window,
		"Crafting": crafting_ui,
		"Map": minimap_ui,
		"QuestLog": quest_log_ui
	}
	
	_close_all_ui()

func _validate_player_refs() -> bool:
	if is_instance_valid(_player_ref) and is_instance_valid(player_inventory):
		return true

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		_player_ref = player
		player_inventory = player.get_node_or_null("Inventory")
		
		if player_inventory:
			_slot_interactor.initialize(player_inventory)
			_cursor_controller.initialize(
				self, player_inventory, _slot_interactor, 
				main_inventory_window, crafting_ui, 
				cursor_item_rect, cursor_amount_label
			)
			if equipment_inventory_ui:
				equipment_inventory_ui.initialize(player_inventory)
			return true
	return false

func _process(delta: float) -> void:
	if DialogueManager.is_active: return
	if not _validate_player_refs(): return

	# 1. Zarządzanie dystansem do skrzyni
	if current_open_chest != null and is_instance_valid(_player_ref):
		var physical_chest = current_open_chest.get_parent()
		if is_instance_valid(physical_chest) and physical_chest is Node2D:
			if _player_ref.global_position.distance_to(physical_chest.global_position) > 150.0:
				_close_all_ui()

	# 2. Zarządzanie padem (ZOPTYMALIZOWANE)
	if is_any_ui_open():
		_handle_gamepad_cursor(delta)
		_handle_item_dropping(delta)
			
	if item_in_hand != null:
		_cursor_controller.update_cursor_position()

# --- WYDZIELONE FUNKCJE (Zasada SRP) ---

func _handle_gamepad_cursor(delta: float) -> void:
	var move_dir = Input.get_vector("Left", "Right", "Up", "Down")
	if move_dir != Vector2.ZERO:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()

		var current_pos = get_viewport().get_mouse_position()
		var new_pos = current_pos + (move_dir * gamepad_cursor_speed * delta)
		var screen_size = get_viewport().get_visible_rect().size
		
		new_pos.x = clamp(new_pos.x, 0, screen_size.x)
		new_pos.y = clamp(new_pos.y, 0, screen_size.y)
		
		# Optymalizacja: Generujemy event TYLKO jeśli kursor faktycznie zmienił pozycję o pełen piksel
		if new_pos.distance_to(_last_mouse_pos) >= 1.0:
			get_viewport().warp_mouse(new_pos)
			var motion_event = InputEventMouseMotion.new()
			motion_event.global_position = new_pos
			motion_event.position = new_pos
			Input.parse_input_event(motion_event)
			_last_mouse_pos = new_pos

func _handle_item_dropping(delta: float) -> void:
	if Input.is_action_pressed("DropItem") and not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
		_drop_hold_time += delta
		if _drop_hold_time > 0.4:
			_drop_tick_time += delta
			if _drop_tick_time > 0.1:
				_cursor_controller.try_drop_hovered_slot(false)
				_drop_tick_time = 0.0 
	else:
		_drop_hold_time = 0.0
		_drop_tick_time = 0.0

# --- GENERYCZNY SYSTEM MENU (Zasada OCP) ---

func toggle_menu(menu_name: String) -> void:
	if not _validate_player_refs(): return
	
	if _active_menu_name == menu_name:
		_close_all_ui()
	else:
		_close_all_ui()
		_active_menu_name = menu_name
		
		match menu_name:
			"Inventory":
				if main_inventory_window: main_inventory_window.show()
				player_panel.open_panel(player_inventory)
				_set_equipment_ui_visible(true)
				if hotbar_panel: hotbar_panel.hide()
				EventBus.set_menu_state(EventBus.MENU_INVENTORY, true)
			
			"Crafting":
				get_tree().paused = true
				if crafting_ui: crafting_ui.show()
				if hotbar_panel: hotbar_panel.show()
				EventBus.set_menu_state(EventBus.MENU_CRAFTING, true)
				
			"Map":
				if minimap_ui: minimap_ui.toggle_large_map(true)
				if hotbar_panel: hotbar_panel.hide()
				if map_open_feedback and is_instance_valid(_player_ref):
					GameFeedback.play_cue(map_open_feedback, null, _player_ref.global_position, _player_ref)
				EventBus.set_menu_state(EventBus.MENU_MAP, true)
				
			"QuestLog":
				get_tree().paused = true
				if quest_log_ui: quest_log_ui.open_log()

func _on_storage_opened(storage_ref: Node) -> void:
	if not _validate_player_refs(): return
	_close_all_ui()
	
	_active_menu_name = "Storage"
	current_open_chest = storage_ref
	_slot_interactor.open_storage = storage_ref
	
	if current_open_chest.has_signal("storage_destroyed") and not current_open_chest.storage_destroyed.is_connected(_close_all_ui):
		current_open_chest.storage_destroyed.connect(_close_all_ui)
		
	if main_inventory_window: main_inventory_window.show()
	player_panel.open_panel(player_inventory)
	chest_panel.open_panel(storage_ref)
	_set_equipment_ui_visible(true)
	if hotbar_panel: hotbar_panel.hide()
	
	EventBus.set_menu_state(EventBus.MENU_STORAGE, true)

func _close_all_ui() -> void:
	get_tree().paused = false
	if item_in_hand != null and is_instance_valid(player_inventory):
		_cursor_controller.return_held_item_to_inventory()
		
	current_open_chest = null
	_slot_interactor.open_storage = null
	_active_menu_name = ""
	
	# Generyczne zamykanie wszystkich paneli
	if main_inventory_window: main_inventory_window.hide()
	if minimap_ui: minimap_ui.toggle_large_map(false)
	if crafting_ui: crafting_ui.hide()
	
	player_panel.close_panel()
	chest_panel.close_panel()
	_set_equipment_ui_visible(false)
	
	if hotbar_panel: hotbar_panel.show()
		
	EventBus.set_menu_state(EventBus.MENU_INVENTORY, false, false)
	EventBus.set_menu_state(EventBus.MENU_CRAFTING, false, false)
	EventBus.set_menu_state(EventBus.MENU_MAP, false, false)
	EventBus.set_menu_state(EventBus.MENU_STORAGE, false, true)

func is_any_ui_open() -> bool:
	return _active_menu_name != "" or DialogueManager.is_active

# --- INPUT ---

func _input(event: InputEvent) -> void:
	if DialogueManager.is_active: return
	
	if event.is_action_pressed(INPUT_GAME_PAUSE):
		if is_any_ui_open():
			_close_all_ui()
			get_viewport().set_input_as_handled()
			
	if event is InputEventMouseButton and not event.pressed:
		if item_in_hand != null and is_any_ui_open():
			if not _cursor_controller.is_mouse_over_inventory_panels():
				if event.button_index == MOUSE_BUTTON_LEFT:
					_cursor_controller.drop_item_from_cursor(true) 
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_cursor_controller.drop_item_from_cursor(false)
					get_viewport().set_input_as_handled()

	if is_any_ui_open():
		if event.is_action_pressed("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released("Interact"):
			_simulate_mouse_click(MOUSE_BUTTON_LEFT, false)
			get_viewport().set_input_as_handled()
			
		if event.is_action_pressed("DropItem"):
			_cursor_controller.try_drop_hovered_slot(Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT))
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active: return
	
	if event.is_action_pressed(INPUT_TOGGLE_INVENTORY):
		toggle_menu("Inventory" if current_open_chest == null else "")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_TOGGLE_CRAFTING): 
		toggle_menu("Crafting")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_TOGGLE_MAP):
		toggle_menu("Map")
		get_viewport().set_input_as_handled()

func _on_open_fullscreen_menu(menu_name: String) -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner: focus_owner.release_focus()
	toggle_menu(menu_name)

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
		get_viewport().warp_mouse(control.get_global_rect().get_center())
		
func _set_equipment_ui_visible(show_panel: bool) -> void:
	if equipment_inventory_ui: equipment_inventory_ui.set_visible(show_panel)