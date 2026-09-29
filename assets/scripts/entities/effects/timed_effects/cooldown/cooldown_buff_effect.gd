extends CooldownModifierEffect
class_name CooldownBuffEffect

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 0.5) -> void:
	super(_duration, _adder, _mult)
	effect_name = "Swift Strikes"
	effect_color = Color.AQUAMARINE
