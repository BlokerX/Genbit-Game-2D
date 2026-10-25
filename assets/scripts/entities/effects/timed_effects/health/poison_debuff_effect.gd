extends HealthOverTimeModifierEffect
class_name PoisonDebuffEffect

func _init(_duration: float = 5.0, _tick_interval: float = 1.0, _hp_per_tick: int = -2) -> void:
	# Nieważne, czy w Inspektorze wpiszesz 4 czy -4, trucizna ZAWSZE zada obrażenia.
	super(_duration, _tick_interval, -abs(_hp_per_tick))
	effect_name = "Poison"
	effect_color = Color.DARK_MAGENTA
