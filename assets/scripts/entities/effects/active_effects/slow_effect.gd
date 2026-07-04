extends SpeedEffect
class_name SlowEffect

func _init(_duration: float = 10.0, _slow_multiplier: float = 0.5) -> void:
	# Wywołujemy bazowy skrypt i podajemy mu mnożnik spowolnienia
	super(_duration, _slow_multiplier)
	
	effect_name = "Slow"
