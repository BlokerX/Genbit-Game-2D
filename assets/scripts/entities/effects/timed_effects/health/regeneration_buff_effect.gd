extends HealthOverTimeModifierEffect
class_name RegenerationBuffEffect

func _init(_duration: float = 10.0, _tick_interval: float = 2.0, _hp_per_tick: int = 5) -> void:
	super(_duration, _tick_interval, _hp_per_tick)
	effect_name = "Regeneration"
	effect_color = Color.PALE_GREEN
	icon = load("res://assets/textures/samples_examples/items/heart.png")
