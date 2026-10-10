class_name UIController extends CanvasLayer

const INPUT_TOGGLE_INVENTORY = "ToggleInventory"
const INPUT_TOGGLE_CRAFTING = "ToggleCrafting"
const INPUT_TOGGLE_MAP = "ToggleMap"
const INPUT_GAME_PAUSE = "Game_Pause"

const EquipmentInventoryUIType = preload("res://assets/scripts/ui/equipment_inventory_ui.gd")
const InventorySlotInteractorType = preload("res://assets/scripts/ui/inventory_slot_interactor.gd")
const InventoryCursorControllerType = preload("res://assets/scripts/ui/inventory_cursor_controller.gd")

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
var _cursor_controller: InventoryCursorControllerType

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
	_cursor_controller = InventoryCursorControllerType.new()
	_cursor_controller.initialize(
		self,
		player_inventory,
		_slot_interactor,
		main_inventory_window,
		crafting_ui,
		cursor_item_rect,
		cursor_amount_label
	)
	_slot_interactor.held_item_changed.connect(_cursor_controller.update_cursor_visuals)
		
	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_on_storage_closed)
	EventBus.slot_clicked.connect(_slot_interactor.handle_slot_clicked)
	EventBus.open_fullscreen_menu.connect(_on_open_fullscreen_menu)
	if not quest_log_ui:
		push_error("UIController nie ma przypisanego dziennika zadań.")
		return
	
	EventBus.player_died.connect(_close_all_ui)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	
	_cursor_controller.update_cursor_visuals()

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
				_cursor_controller.try_drop_hovered_slot(false)
				_drop_tick_time = 0.0 
	else:
		_drop_hold_time = 0.0
		_drop_tick_time = 0.0
			
	if item_in_hand != null:
		_cursor_controller.update_cursor_position()


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
		_cursor_controller.return_held_item_to_inventory()
		
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
			if not _cursor_controller.is_mouse_over_inventory_panels():
				if event.button_index == MOUSE_BUTTON_LEFT:
					_cursor_controller.drop_item_from_cursor(true)  # Zrzut całego stacka
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_cursor_controller.drop_item_from_cursor(false) # Zrzut tylko jednej sztuki
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
				_cursor_controller.try_drop_hovered_slot(true)
			else:
				_cursor_controller.try_drop_hovered_slot(false)
			get_viewport().set_input_as_handled()

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
