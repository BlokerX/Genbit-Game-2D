extends MaxHealthModifierEffect
class_name MaxHealthDebuffEffect

func _init(_duration: float = 30.0, _adder: int = -25) -> void:
	super(_duration, _adder)
	effect_name = "Frail"
	effect_color = Color.PALE_VIOLET_RED
