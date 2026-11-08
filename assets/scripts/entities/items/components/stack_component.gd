class_name StackComponent
extends ItemComponent
## Pozwala łączyć identyczne przedmioty w stosy (stacki) o określonym limicie.

const DEFAULT_MAX_STACK: int = 100
const DEFAULT_INITIAL_AMOUNT: int = 1

@export var max_stack: int = DEFAULT_MAX_STACK
## Opcjonalnie: czy wyświetlać informację o limicie stosu również w dymku tooltipa?
@export var show_stack_in_tooltip: bool = false

## Ustawiamy domyślną ilość, gdy przedmiot jest tworzony po raz pierwszy.
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("amount"):
		item_instance.state["amount"] = DEFAULT_INITIAL_AMOUNT

func get_tooltip_info(item_instance: ItemInstance) -> String:
	if not show_stack_in_tooltip or item_instance == null:
		return ""
	var current_amount: int = item_instance.state.get("amount", DEFAULT_INITIAL_AMOUNT)
	return "Ilość: %d / %d\n" % [current_amount, max_stack]

func get_hud_info(item_instance: ItemInstance, is_advanced: bool) -> String:
	if item_instance == null:
		return ""
	var current_amount: int = item_instance.state.get("amount", DEFAULT_INITIAL_AMOUNT)
	if is_advanced:
		return "Ilość: " + str(current_amount) + " / " + str(max_stack) + "\n"
	elif max_stack > DEFAULT_INITIAL_AMOUNT:
		return "Ilość: " + str(current_amount) + "\n"
	return ""
