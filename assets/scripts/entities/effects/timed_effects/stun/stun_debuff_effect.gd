extends StunModifierEffect
class_name StunDebuffEffect

func _init(_duration: float = 10.0, _adder: float = -0.2, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Lightweight"
	effect_color = Color.THISTLE
