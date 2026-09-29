extends TimedEffect
class_name MaxHealthModifierEffect

@export_category("Modyfikatory Maksymalnego HP")
## Wartość dodawana do Max HP. Dodatnia zwiększa, ujemna zmniejsza.
@export var max_health_adder: int = 50

func _init(_duration: float = 30.0, _adder: int = 50) -> void:
	effect_name = "Max Health Modifier"
	effect_color = Color.WHITE
	duration = _duration
	tick_interval = 0.0
	max_health_adder = _adder

func on_effect_start(target: Node2D) -> void:
	if target.get("health_stats_script") != null:
		if max_health_adder > 0:
			target.health_stats_script.boost_max_health(max_health_adder)
		elif max_health_adder < 0:
			target.health_stats_script.reduce_max_health(abs(max_health_adder))

func on_effect_end(target: Node2D) -> void:
	if target.get("health_stats_script") != null:
		# Odwracamy proces przy znikaniu efektu
		if max_health_adder > 0:
			target.health_stats_script.reduce_max_health(max_health_adder)
		elif max_health_adder < 0:
			target.health_stats_script.boost_max_health(abs(max_health_adder))
