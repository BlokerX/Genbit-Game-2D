extends TimedEffect
class_name ArmorModifierEffect

@export_category("Modyfikatory Pancerza")
@export var armor_adder: float = 0.0
@export var armor_multiplier: float = 1.0

func _init(_duration: float = 10.0, _adder: float = 0.0, _mult: float = 1.0):
	effect_name = "Armor Modifier"
	effect_color = Color.SLATE_GRAY
	duration = _duration
	tick_interval = 0.0
	armor_adder = _adder
	armor_multiplier = _mult
	effect_category = EffectCategory.STAT_DEBUFF if (_adder < 0.0 or _mult < 1.0) else EffectCategory.STAT_BUFF

func on_effect_start(target: Node2D) -> void:
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script
		stats.armor_adder = snappedf(stats.armor_adder + armor_adder, 0.0001)
		stats.armor_multiplier = snappedf(stats.armor_multiplier * armor_multiplier, 0.0001)

func on_effect_end(target: Node2D) -> void:
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script
		stats.armor_adder = snappedf(stats.armor_adder - armor_adder, 0.0001)
		if armor_multiplier != 0.0:
			stats.armor_multiplier = snappedf(stats.armor_multiplier / armor_multiplier, 0.0001)
