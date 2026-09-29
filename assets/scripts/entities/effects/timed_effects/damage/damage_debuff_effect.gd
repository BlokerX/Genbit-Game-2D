extends DamageModifierEffect
class_name DamageDebuffEffect

func _init(_duration: float = 10.0, _adder: float = -5.0, _mult: float = 1.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Weakness"
	effect_color = Color.SLATE_GRAY
