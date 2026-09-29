extends MaxHealthModifierEffect
class_name MaxHealthBuffEffect

func _init(_duration: float = 30.0, _adder: int = 50) -> void:
	super(_duration, _adder)
	effect_name = "Vitality"
	effect_color = Color.YELLOW_GREEN
