extends Node

var flags: Dictionary = {}

## Ustawia flagę narracyjną
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

## Sprawdza, czy flaga narracyjna istnieje i ma wartość 'true'
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func reset_state() -> void:
	flags.clear()
