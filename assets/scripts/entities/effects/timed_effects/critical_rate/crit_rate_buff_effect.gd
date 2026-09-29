extends CritRateModifierEffect
class_name CritRateBuffEffect

func _init(_duration: float = 10.0, _adder: float = 0.2, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Precision"
	effect_color = Color.GOLD
