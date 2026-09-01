extends Effect
class_name SetFlagEffect

@export var flag_name: String = "quest_name"
@export var flag_value: bool = true

func _init() -> void:
	effect_name = "Set Flag"

func apply_effect(_target: Node2D) -> bool:
	DialogueState.set_flag(flag_name, flag_value)
	print("Dialog: Ustawiono flagę fabularną -> ", flag_name)
	return true
