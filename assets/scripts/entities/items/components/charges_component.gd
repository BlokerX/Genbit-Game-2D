class_name ChargesComponent
extends ItemComponent
## Komponent ładunków (Charges) dla przedmiotów wielokrotnego użytku wymagających odnowienia/naładowania.

const DEFAULT_MAX_CHARGES: int = 5

@export_category("Ładunki (Charges)")
## Maksymalna ilość użyć przedmiotu przed koniecznością jego odnowienia.
@export var max_charges: int = DEFAULT_MAX_CHARGES

## Inicjalizujemy stan ładunków przy pierwszym utworzeniu instancji.
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("charges"):
		item_instance.state["charges"] = max_charges

func get_tooltip_info(item_instance: ItemInstance) -> String:
	if item_instance == null:
		return ""
	var current_charges: int = item_instance.state.get("charges", max_charges)
	return "Ładunki: " + str(current_charges) + " / " + str(max_charges) + "\n"

func get_hud_info(item_instance: ItemInstance, is_advanced: bool) -> String:
	if item_instance == null:
		return ""
	var current_charges: int = item_instance.state.get("charges", max_charges)
	if is_advanced:
		return "Ładunki: " + str(current_charges) + " / " + str(max_charges) + "\n"
	return "Pozostałe ładunki: " + str(current_charges) + "\n"
