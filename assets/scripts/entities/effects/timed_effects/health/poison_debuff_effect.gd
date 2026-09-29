extends HealthOverTimeModifierEffect
class_name PoisonDebuffEffect

func _init(_duration: float = 5.0, _tick_interval: float = 1.0, _hp_per_tick: int = -2) -> void:
	super(_duration, _tick_interval, _hp_per_tick)
	effect_name = "Poison"
	effect_color = Color.DARK_MAGENTA
