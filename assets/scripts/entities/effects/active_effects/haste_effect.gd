extends SpeedEffect
class_name HasteEffect

func _init(_duration: float = 10.0, _haste_multiplier: float = 2) -> void:
	# Wywołujemy bazowy skrypt i podajemy mu nasz mnożnik powiększenia prędkości
	super(_duration, _haste_multiplier)
	
	effect_name = "Haste"
	effect_color = Color.ORANGE_RED
