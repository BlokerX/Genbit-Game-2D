extends RangeModifierEffect
class_name RangeBuffEffect

func _init(_duration: float = 10.0, _adder: float = 50.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Eagle Eye"
	effect_color = Color.GREEN_YELLOW
