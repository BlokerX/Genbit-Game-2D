extends Effect
class_name DamageEffect
## Efekt natychmiastowych obrażeń fizycznych obsługujący przebicie pancerza, reakcję wizualną trafienia oraz odbicie Cierni (Thorns).

@export var damage_amount : int
@export var armor_penetration : float = 0.0
var is_reflected_damage: bool = false # Zabezpieczenie przed pętlą cierni!

func _init(_damage_amount: int = 0, _armor_penetration: float = 0.0, _is_reflected: bool = false) -> void:
	damage_amount = _damage_amount
	armor_penetration = _armor_penetration
	is_reflected_damage = _is_reflected
	effect_name = "Damage"
	effect_category = EffectCategory.PHYSICAL_DAMAGE

func apply_potency_multiplier(multiplier: float) -> void:
	damage_amount = maxi(1, int(round(float(damage_amount) * maxf(0.0, multiplier))))

func apply_effect(target : Node2D) -> bool:
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script

		# 1. ZADANIE OBRAŻEŃ (LifeStatsComponent zajmie się resztą)
		stats.take_damage(damage_amount, armor_penetration)
		print("Zadano obrażenia: ", damage_amount, " (Penetracja: ", armor_penetration * 100, "%)")

		# Wizualna reakcja postaci na otrzymany cios (odskok i rozbłysk trafienia)
		if target.has_method("play_hit_reaction"):
			var hit_origin: Vector2 = source_position
			if hit_origin == Vector2.ZERO and is_instance_valid(source_entity):
				hit_origin = source_entity.global_position
			target.call("play_hit_reaction", hit_origin)

		if (
			is_instance_valid(source_entity)
			and source_entity != target
			and source_entity.has_method("notify_damage_dealt")
		):
			source_entity.call("notify_damage_dealt", target)

		# 2. LOGIKA CIERNI (THORNS REFLECTION)
		# Upewniamy się, że to nie jest już odbity cios, oraz że sprawca żyje i nie bije sam siebie
		if not is_reflected_damage and is_instance_valid(source_entity) and source_entity != target:
			var effective_armor: float = float(stats.get_total_armor()) * (1.0 - armor_penetration)
			var effective_damage: int = maxi(1, damage_amount - int(effective_armor))
			var reflected_dmg: int = stats.thorns_damage + int(float(effective_damage) * stats.thorns_percent)

			if reflected_dmg > 0:
				print("Ciernie! Odbijanie ", reflected_dmg, " DMG w ", source_entity.name)
				var thorn_effect := DamageEffect.new(reflected_dmg, 0.0, true)
				thorn_effect.source_entity = target
				thorn_effect.source_position = target.global_position

				if source_entity.has_method("receive_effect"):
					source_entity.receive_effect(thorn_effect)
				else:
					thorn_effect.apply_effect(source_entity)

		return true

	return false

func is_offensive() -> bool:
	return true
