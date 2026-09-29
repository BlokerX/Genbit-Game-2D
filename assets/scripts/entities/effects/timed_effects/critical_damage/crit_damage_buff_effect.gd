extends CritDamageModifierEffect
class_name CritDamageBuffEffect

func _init(_duration: float = 10.0, _adder: float = 15.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Lethal Force"
	effect_color = Color.DARK_ORANGE
