extends RangeModifierEffect
class_name RangeDebuffEffect

func _init(_duration: float = 10.0, _adder: float = -50.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Nearsighted"
	effect_color = Color.DARK_OLIVE_GREEN
