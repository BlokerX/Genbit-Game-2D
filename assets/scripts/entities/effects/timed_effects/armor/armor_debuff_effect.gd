extends ArmorModifierEffect
class_name ArmorDebuffEffect

func _init(_duration: float = 10.0, _adder: float = -10.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Vulnerable"
	effect_color = Color.PALE_VIOLET_RED
