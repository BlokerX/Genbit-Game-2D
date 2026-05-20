extends ResizeEffect
class_name LiliputEffect

func _init(_duration: float = 30.0, _liliput_scaler: float = 0.8) -> void:
	# Wywołujemy _init() z ResizeEffect (klasy wyższej)
	super(_duration, _liliput_scaler)
	
	# Nadpisujemy tylko nazwę efektu
	effect_name = "Liliput"
