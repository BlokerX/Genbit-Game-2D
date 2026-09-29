extends CooldownModifierEffect
class_name CooldownDebuffEffect

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 2.0) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Sluggish"
	effect_color = Color.SLATE_BLUE
