extends ResizeEffect
class_name GiantEffect

func _init(_duration: float = 30.0, _giant_scaler: float = 1.25) -> void:
	# Wywołujemy _init() z ResizeEffect z mnożnikiem 2.0
	super(_duration, _giant_scaler)
	
	effect_name = "Giant"
