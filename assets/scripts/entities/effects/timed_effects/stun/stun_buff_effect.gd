extends StunModifierEffect
class_name StunBuffEffect

func _init(_duration: float = 10.0, _adder: float = 0.5, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Heavy Blows"
	effect_color = Color.MEDIUM_PURPLE
