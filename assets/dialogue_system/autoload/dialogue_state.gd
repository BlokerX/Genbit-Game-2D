extends Node

var flags: Dictionary = {}
var counters: Dictionary = {} # NOWE: Pamięć liczników

## Ustawia flagę narracyjną
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

## Sprawdza, czy flaga narracyjna istnieje i ma wartość 'true'
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func increment_counter(counter_name: String) -> void:
	counters[counter_name] = get_counter(counter_name) + 1

func get_counter(counter_name: String) -> int:
	return counters.get(counter_name, 0)

func reset_state() -> void:
	flags.clear()
	counters.clear()
