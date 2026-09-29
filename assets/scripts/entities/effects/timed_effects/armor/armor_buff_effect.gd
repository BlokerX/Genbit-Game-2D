extends ArmorModifierEffect
class_name ArmorBuffEffect

func _init(_duration: float = 15.0, _adder: float = 10.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Ironskin"
	effect_color = Color.STEEL_BLUE
