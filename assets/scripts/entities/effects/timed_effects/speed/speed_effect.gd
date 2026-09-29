extends SpeedModifierEffect
class_name SpeedEffect

func _init(_duration: float = 10.0, _speed_multiplier: float = 2) -> void:
	# Wywołujemy bazowy skrypt i podajemy mu nasz mnożnik powiększenia prędkości
	super(_duration, _speed_multiplier)
	
	effect_name = "Speed"
	effect_color = Color.ORANGE_RED
