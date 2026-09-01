extends Node

## Zarządzanie widocznością UI
signal open_storage_ui(storage_reference: Node)
signal close_storage_ui()

## Przekazuje kto został kliknięty, który to slot i jakim przyciskiem (-1 to Shift+Lewy)
signal slot_clicked(parent_reference: Node, slot_index: int, button_index: int)

signal ui_state_changed(is_open: bool)

# --- ZAAWANSOWANY SYSTEM WIDOCZNOŚCI HUD ---
signal hud_visibility_requested()

## Czy ukrywać główny interfejs gry (HUD) w oknach i dialogach?
var active_menus: Dictionary = {
	"inventory": false,
	"storage": false,
	"crafting": false,
	"map": false,
	"dialogue": false,
	"pause": false
}

## Funkcja aktualizująca dany stan UI i odświeżająca HUD
func set_menu_state(menu_name: String, is_open: bool) -> void:
	if active_menus.has(menu_name):
		active_menus[menu_name] = is_open
		hud_visibility_requested.emit()
