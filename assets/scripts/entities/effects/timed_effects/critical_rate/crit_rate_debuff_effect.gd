extends CritRateModifierEffect
class_name CritRateDebuffEffect

func _init(_duration: float = 10.0, _adder: float = -0.2, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Clumsy"
	effect_color = Color.DARK_KHAKI
