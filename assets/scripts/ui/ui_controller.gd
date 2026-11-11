class_name UIController
extends CanvasLayer
## Główny kontroler interfejsu rozgrywki zarządzający otwieraniem okien, kursorem pada,
## konfigurowalnym zatrzymywaniem czasu gry (pauzą) oraz synchronizacją widoczności HUD-u.

const INPUT_TOGGLE_INVENTORY: String = "ToggleInventory"
const INPUT_TOGGLE_CRAFTING: String = "ToggleCrafting"
const INPUT_TOGGLE_MAP: String = "ToggleMap"
const INPUT_GAME_PAUSE: String = "Game_Pause"

const CHEST_AUTO_CLOSE_DISTANCE_PX: float = 150.0
const DROP_HOLD_INITIAL_DELAY_SEC: float = 0.4
const DROP_HOLD_TICK_INTERVAL_SEC: float = 0.1
const MIN_CURSOR_MOVE_DELTA_PX: float = 1.0

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

@export_category("Zatrzymywanie Czasu (Pauza Okien)")
## Czy otwarcie Ekwipunku (I) ma zatrzymywać czas gry?
@export var pause_on_inventory: bool = false
## Czy otwarcie Skrzyni / Magazynu ma zatrzymywać czas gry?
@export var pause_on_storage: bool = false
## Czy otwarcie okna Craftingu (C) ma zatrzymywać czas gry? (Domyślnie: false - crafting w czasie rzeczywistym).
@export var pause_on_crafting: bool = false
## Czy otwarcie dużej Mapy (M) ma zatrzymywać czas gry?
@export var pause_on_map: bool = false
## Czy otwarcie Dziennika Zadań (J) ma zatrzymywać czas gry?
@export var pause_on_quest_log: bool = false
## Czy rozpoczęcie Konwersacji (Dialogu z NPC) ma zatrzymywać czas gry?
@export var pause_on_dialogue: bool = false

@export_group("Oprawa dźwiękowa")
@export var map_open_feedback: FeedbackCue = preload("res://assets/data/feedback/ui/map_open.tres")

@export_category("Gamepad UI")
@export var gamepad_cursor_speed: float = 700.0

# --- REFAKTORYZACJA SOLID (Zamiast dziesiątek flag is_open) ---
var _active_menu_name: String = ""
var _ui_panels: Dictionary = {}
## Mapa reguł określająca, które klucze menu (EventBus.MENU_*) zatrzymują czas gry (OCP).
var _menu_pause_rules: Dictionary = {}

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

var _drop_hold_time: float = 0.0
var _drop_tick_time: float = 0.0
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_slot_interactor = InventorySlotInteractorType.new()
	_cursor_controller = InventoryCursorControllerType.new()

	_rebuild_pause_rules()
	_validate_player_refs()

	_slot_interactor.held_item_changed.connect(_cursor_controller.update_cursor_visuals)
	EventBus.open_storage_ui.connect(_on_storage_opened)
	EventBus.close_storage_ui.connect(_close_all_ui)
	EventBus.slot_clicked.connect(_slot_interactor.handle_slot_clicked)
	EventBus.open_fullscreen_menu.connect(_on_open_fullscreen_menu)
	EventBus.player_died.connect(_close_all_ui)
	EventBus.hud_visibility_requested.connect(_on_hud_visibility_requested)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

	# Synchronizacja z QuestLogUI (zamknięcie przyciskiem X lub skrótem klawiszowym oraz reguła pauzy)
	if quest_log_ui != null:
		if "pause_game_when_open" in quest_log_ui:
			quest_log_ui.pause_game_when_open = pause_on_quest_log
		if quest_log_ui.has_signal("log_closed") and not quest_log_ui.log_closed.is_connected(_on_quest_log_closed_internally):
			quest_log_ui.log_closed.connect(_on_quest_log_closed_internally)

	_cursor_controller.update_cursor_visuals()

	# Rejestracja paneli do generycznego systemu (OCP)
	_ui_panels = {
		"Inventory": main_inventory_window,
		"Crafting": crafting_ui,
		"Map": minimap_ui,
		"QuestLog": quest_log_ui
	}

	_close_all_ui()

	# Gwarantujemy odtworzenie zapisanych ustawień widoczności i skali GUI po każdym załadowaniu sceny gry
	if GlobalSettings.has_method("apply_gui_visibility_to_tree"):
		GlobalSettings.apply_gui_visibility_to_tree()
		GlobalSettings.call_deferred("apply_gui_visibility_to_tree")

## Inicjalizuje słownik reguł pauzowania czasu na podstawie właściwości @export z Inspektora.
func _rebuild_pause_rules() -> void:
	_menu_pause_rules = {
		EventBus.MENU_INVENTORY: pause_on_inventory,
		EventBus.MENU_STORAGE: pause_on_storage,
		EventBus.MENU_CRAFTING: pause_on_crafting,
		EventBus.MENU_MAP: pause_on_map,
		EventBus.MENU_QUEST_LOG: pause_on_quest_log,
		EventBus.MENU_DIALOGUE: pause_on_dialogue,
		EventBus.MENU_PAUSE: true
	}

## Pozwala dynamicznie zarejestrować lub zmienić regułę zatrzymywania czasu dla dowolnego okna (SOLID - OCP).
func set_menu_pause_rule(menu_key: String, should_pause: bool) -> void:
	_menu_pause_rules[menu_key] = should_pause
	_sync_tree_pause_state()

## Sprawdza, czy którekolwiek z aktualnie aktywnych okien wymaga zatrzymania czasu gry.
func should_pause_tree() -> bool:
	if EventBus.active_menus.get(EventBus.MENU_PAUSE, false):
		return true
	for menu_key in _menu_pause_rules.keys():
		if EventBus.active_menus.get(menu_key, false) and bool(_menu_pause_rules[menu_key]):
			return true
	if DialogueManager.is_active and pause_on_dialogue:
		return true
	return false

## Synchronizuje stan get_tree().paused z aktualnie otwartymi oknami i ich konfiguracją pauzy.
func _sync_tree_pause_state() -> void:
	if not is_inside_tree():
		return
	_rebuild_pause_rules()
	if quest_log_ui != null and "pause_game_when_open" in quest_log_ui:
		quest_log_ui.pause_game_when_open = pause_on_quest_log
	get_tree().paused = should_pause_tree()

func _on_hud_visibility_requested() -> void:
	_sync_tree_pause_state()
	call_deferred("_sync_tree_pause_state")

## Przywraca widoczność paska Hotbar wyłącznie wtedy, gdy pozwala na to opcja GlobalSettings.show_hotbar.
func _restore_hotbar_visibility() -> void:
	if hotbar_panel:
		hotbar_panel.visible = GlobalSettings.show_hotbar

func _on_quest_log_closed_internally() -> void:
	if _active_menu_name == "QuestLog":
		_active_menu_name = ""
		_restore_hotbar_visibility()
	_sync_tree_pause_state()

func _validate_player_refs() -> bool:
	if is_instance_valid(_player_ref) and is_instance_valid(player_inventory):
		return true

	var player: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
	if player != null:
		_player_ref = player
		player_inventory = player.get_node_or_null("Inventory") as Inventory
		if player_inventory != null:
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
	if DialogueManager.is_active:
		return
	if not _validate_player_refs():
		return

	# 1. Zarządzanie dystansem do skrzyni
	if current_open_chest != null and is_instance_valid(_player_ref):
		var physical_chest: Node = current_open_chest.get_parent()
		if is_instance_valid(physical_chest) and physical_chest is Node2D:
			if _player_ref.global_position.distance_to((physical_chest as Node2D).global_position) > CHEST_AUTO_CLOSE_DISTANCE_PX:
				_close_all_ui()

	# 2. Zarządzanie padem (ZOPTYMALIZOWANE)
	if is_any_ui_open():
		_handle_gamepad_cursor(delta)
		_handle_item_dropping(delta)

	if item_in_hand != null:
		_cursor_controller.update_cursor_position()

# --- WYDZIELONE FUNKCJE (Zasada SRP) ---
func _handle_gamepad_cursor(delta: float) -> void:
	var move_dir: Vector2 = Input.get_vector("Left", "Right", "Up", "Down")
	if move_dir != Vector2.ZERO:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()

		var current_pos: Vector2 = get_viewport().get_mouse_position()
		var new_pos: Vector2 = current_pos + (move_dir * gamepad_cursor_speed * delta)
		var screen_size: Vector2 = get_viewport().get_visible_rect().size
		new_pos.x = clampf(new_pos.x, 0.0, screen_size.x)
		new_pos.y = clampf(new_pos.y, 0.0, screen_size.y)

		# Optymalizacja: Generujemy event TYLKO jeśli kursor faktycznie zmienił pozycję o pełen piksel
		if new_pos.distance_to(_last_mouse_pos) >= MIN_CURSOR_MOVE_DELTA_PX:
			get_viewport().warp_mouse(new_pos)
			var motion_event: InputEventMouseMotion = InputEventMouseMotion.new()
			motion_event.global_position = new_pos
			motion_event.position = new_pos
			Input.parse_input_event(motion_event)
			_last_mouse_pos = new_pos

func _handle_item_dropping(delta: float) -> void:
	if Input.is_action_pressed("DropItem") and not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
		_drop_hold_time += delta
		if _drop_hold_time > DROP_HOLD_INITIAL_DELAY_SEC:
			_drop_tick_time += delta
			if _drop_tick_time > DROP_HOLD_TICK_INTERVAL_SEC:
				_cursor_controller.try_drop_hovered_slot(false)
				_drop_tick_time = 0.0 
	else:
		_drop_hold_time = 0.0
		_drop_tick_time = 0.0

# --- GENERYCZNY SYSTEM MENU (Zasada OCP) ---
func toggle_menu(menu_name: String) -> void:
	if not _validate_player_refs():
		return

	if _active_menu_name == menu_name:
		_close_all_ui()
	else:
		_close_all_ui()
		_active_menu_name = menu_name

		match menu_name:
			"Inventory":
				EventBus.set_menu_state(EventBus.MENU_INVENTORY, true)
				if main_inventory_window:
					main_inventory_window.show()
				player_panel.open_panel(player_inventory)
				_set_equipment_ui_visible(true)
				if hotbar_panel:
					hotbar_panel.hide()

			"Crafting":
				EventBus.set_menu_state(EventBus.MENU_CRAFTING, true)
				if crafting_ui:
					crafting_ui.show()
				_restore_hotbar_visibility()

			"Map":
				EventBus.set_menu_state(EventBus.MENU_MAP, true)
				if minimap_ui:
					minimap_ui.toggle_large_map(true)
				if hotbar_panel:
					hotbar_panel.hide()
				if map_open_feedback and is_instance_valid(_player_ref):
					GameFeedback.play_cue(map_open_feedback, null, _player_ref.global_position, _player_ref)

			"QuestLog":
				if quest_log_ui:
					if "pause_game_when_open" in quest_log_ui:
						quest_log_ui.pause_game_when_open = pause_on_quest_log
					quest_log_ui.open_from_menu_request()

		_sync_tree_pause_state()

func _on_storage_opened(storage_ref: Node) -> void:
	if not _validate_player_refs():
		return

	_close_all_ui()
	_active_menu_name = "Storage"
	current_open_chest = storage_ref
	_slot_interactor.open_storage = storage_ref

	if current_open_chest.has_signal("storage_destroyed") and not current_open_chest.storage_destroyed.is_connected(_close_all_ui):
		current_open_chest.storage_destroyed.connect(_close_all_ui)

	EventBus.set_menu_state(EventBus.MENU_STORAGE, true)
	if main_inventory_window:
		main_inventory_window.show()
	player_panel.open_panel(player_inventory)
	chest_panel.open_panel(storage_ref)
	_set_equipment_ui_visible(true)
	if hotbar_panel:
		hotbar_panel.hide()
	_sync_tree_pause_state()

func _close_all_ui() -> void:
	if item_in_hand != null and is_instance_valid(player_inventory):
		_cursor_controller.return_held_item_to_inventory()

	current_open_chest = null
	_slot_interactor.open_storage = null
	_active_menu_name = ""

	# Generyczne zamykanie zarejestrowanych paneli ze słownika _ui_panels (OCP)
	for panel_key in _ui_panels:
		var panel_node: Node = _ui_panels[panel_key]
		if not is_instance_valid(panel_node):
			continue
		if panel_node is Minimap:
			(panel_node as Minimap).toggle_large_map(false)
		elif panel_node.has_method("close_log"):
			if panel_node.get("visible") == true:
				panel_node.call("close_log")
		elif panel_node.has_method("hide"):
			panel_node.call("hide")

	player_panel.close_panel()
	chest_panel.close_panel()
	_set_equipment_ui_visible(false)

	_restore_hotbar_visibility()

	EventBus.set_menu_state(EventBus.MENU_INVENTORY, false, false)
	EventBus.set_menu_state(EventBus.MENU_CRAFTING, false, false)
	EventBus.set_menu_state(EventBus.MENU_MAP, false, false)
	EventBus.set_menu_state(EventBus.MENU_QUEST_LOG, false, false)
	EventBus.set_menu_state(EventBus.MENU_STORAGE, false, true)
	_sync_tree_pause_state()

func is_any_ui_open() -> bool:
	return _active_menu_name != "" or DialogueManager.is_active

# --- INPUT ---
func _input(event: InputEvent) -> void:
	if DialogueManager.is_active:
		return

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
	if DialogueManager.is_active:
		return

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
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	toggle_menu(menu_name)

func _simulate_mouse_click(button_idx: int, is_pressed: bool) -> void:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null:
		return

	var target: Node = hovered
	while target != null:
		if target is BaseButton:
			if is_pressed and button_idx == MOUSE_BUTTON_LEFT:
				target.emit_signal("pressed")
			return
		if target.has_method("_gui_input") and target is Control:
			var ev: InputEventMouseButton = InputEventMouseButton.new()
			ev.button_index = button_idx as MouseButton
			ev.pressed = is_pressed
			ev.position = (target as Control).get_local_mouse_position()
			target.call("_gui_input", ev)
			return
		target = target.get_parent()

func _on_gui_focus_changed(control: Control) -> void:
	if is_any_ui_open() and control != null:
		get_viewport().warp_mouse(control.get_global_rect().get_center())

func _set_equipment_ui_visible(show_panel: bool) -> void:
	if equipment_inventory_ui:
		equipment_inventory_ui.set_visible(show_panel)
