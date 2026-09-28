extends Node

## Zarządzanie widocznością UI
signal open_storage_ui(storage_reference: Node)
signal close_storage_ui()

## Przekazuje kto został kliknięty, który to slot i jakim przyciskiem (-1 to Shift+Lewy)
signal slot_clicked(parent_reference: Node, slot_index: int, button_index: int)

signal ui_state_changed(is_open: bool)

# --- ZAAWANSOWANY SYSTEM WIDOCZNOŚCI HUD ---
signal hud_visibility_requested()

signal open_fullscreen_menu(menu_name: String)

signal story_event_triggered(event_name: String)

# --- GLOBALNA MAGISTRALA ROZGRYWKI (Pod Questy i Osiągnięcia) ---
## Uniwersalny sygnał na wszystko, co robi gracz w świecie.
## event_type np: "item_collected", "enemy_killed", "action_performed"
## event_data np: {"item_id": &"wood", "amount": 5}
signal game_event_occurred(event_type: String, event_data: Dictionary)

signal player_died

# --- STAŁE (Eliminacja literówek) ---
const MENU_INVENTORY = "inventory"
const MENU_STORAGE = "storage"
const MENU_CRAFTING = "crafting"
const MENU_MAP = "map"
const MENU_DIALOGUE = "dialogue"
const MENU_QUEST_LOG = "quest_log"
const MENU_PAUSE = "pause"

var active_menus: Dictionary = {
	MENU_INVENTORY: false,
	MENU_STORAGE: false,
	MENU_CRAFTING: false,
	MENU_MAP: false,
	MENU_DIALOGUE: false,
	MENU_QUEST_LOG: false,
	MENU_PAUSE: false
}

# --- NOWOŚĆ: REJESTR ZDARZEŃ FABULARNYCH ---
## Pamięć wszystkich zdarzeń, które wydarzyły się w grze. 
## Służy do synchronizacji obiektów wybudzanych z chunków.
var story_events_history: Array[String] = []

func _ready() -> void:
	# Automatycznie nasłuchujemy własnego sygnału, aby zapisywać go do historii
	story_event_triggered.connect(_record_story_event)

## Zapisuje hasło do rejestru (uruchamiane automatycznie przez sygnał)
func _record_story_event(event_name: String) -> void:
	if not story_events_history.has(event_name):
		story_events_history.append(event_name)
		print("EventBus: Zapisano do historii zdarzenie -> ", event_name)

## Sprawdza, czy dane zdarzenie fabularne już się kiedykolwiek wydarzyło.
func has_story_event_occurred(event_name: String) -> bool:
	return story_events_history.has(event_name)

## Funkcja aktualizująca dany stan UI. 
## 'emit_update' pozwala na cichą zmianę przy zamykaniu wielu okien naraz.
func set_menu_state(menu_name: String, is_open: bool, emit_update: bool = true) -> void:
	if active_menus.has(menu_name):
		active_menus[menu_name] = is_open
		
		if emit_update:
			hud_visibility_requested.emit()
			# Tarcza Gracza: Zawsze sprawdzamy, czy COKOLWIEK jest otwarte!
			ui_state_changed.emit(is_any_menu_open())

## Zwraca true, jeśli chociaż jedno menu z systemu jest aktywne
func is_any_menu_open() -> bool:
	for is_open in active_menus.values():
		if is_open: return true
	return false

## Resetuje stan wszystkich menu do wartości domyślnych (zamknięte)
func reset(emit_update: bool = true) -> void:
	var was_any_open = is_any_menu_open()
	
	for menu_name in active_menus.keys():
		active_menus[menu_name] = false
		
	if emit_update and was_any_open:
		hud_visibility_requested.emit()
		ui_state_changed.emit(false)

## Wymusza wyczyszczenie historii (używane np. przy wychodzeniu do Menu Głównego z SaveManagerem)
func clear_history() -> void:
	story_events_history.clear()
	print("EventBus: Historia zdarzeń fabularnych została wyczyszczona.")
