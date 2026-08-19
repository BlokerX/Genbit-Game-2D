class_name ChargesComponent
extends ItemComponent

@export_category("Ładunki (Charges)")
## Maksymalna ilość użyć przedmiotu przed koniecznością jego odnowienia
@export var max_charges: int = 5

## Inicjalizujemy stan ładunków przy pierwszym utworzeniu instancji
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("charges"):
		item_instance.state["charges"] = max_charges
