class_name BackpackComponent
extends ItemComponent
## Komponent plecaka zwiększający liczbę dostępnych slotów w ekwipunku gracza po założeniu.

const DEFAULT_EXTRA_SLOTS_COUNT: int = 5

@export_category("Ustawienia Plecaka")
## Liczba dodatkowych miejsc, o które plecak powiększa ekwipunek.
@export var extra_slots_count: int = DEFAULT_EXTRA_SLOTS_COUNT

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	return "Dodatkowe miejsce: +" + str(extra_slots_count) + " slotów\n"

func get_hud_info(_item_instance: ItemInstance, _is_advanced: bool) -> String:
	return "Pojemność plecaka: +" + str(extra_slots_count) + " slotów\n"
