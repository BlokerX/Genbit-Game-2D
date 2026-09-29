extends TimedEffect
class_name HealthOverTimeModifierEffect

@export_category("Modyfikatory Zdrowia w Czasie")
## Wartość na tick. Powyżej 0 = leczy. Poniżej 0 = zadaje obrażenia.
@export var hp_per_tick: int = 5

func _init(_duration: float = 10.0, _tick_interval: float = 2.0, _hp_per_tick: int = 5) -> void:
	effect_name = "Health Over Time"
	effect_color = Color.WHITE
	duration = _duration
	tick_interval = _tick_interval
	hp_per_tick = _hp_per_tick

func on_effect_tick(target: Node2D) -> void:
	if target.get("health_stats_script") != null:
		if hp_per_tick > 0:
			target.health_stats_script.heal(hp_per_tick)
			print(effect_name, " leczy o ", hp_per_tick, " HP.")
		elif hp_per_tick < 0:
			target.health_stats_script.take_damage(abs(hp_per_tick))
			print(effect_name, " zadaje ", abs(hp_per_tick), " obrażeń.")
