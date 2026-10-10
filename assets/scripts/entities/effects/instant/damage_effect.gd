extends Effect
class_name DamageEffect

@export var damage_amount : int
@export var armor_penetration : float = 0.0
var is_reflected_damage: bool = false # Zabezpieczenie przed pętlą cierni!

func _init(_damage_amount: int = 0, _armor_penetration: float = 0.0, _is_reflected: bool = false):
	damage_amount = _damage_amount
	armor_penetration = _armor_penetration
	is_reflected_damage = _is_reflected
	effect_name = "Damage"

func apply_effect(target : Node2D) -> bool:
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script
		
		# 1. ZADANIE OBRAŻEŃ (Twój zaktualizowany skrypt z LifeStatsComponent zajmie się resztą)
		stats.take_damage(damage_amount, armor_penetration)
		print("Zadano obrażenia: ", damage_amount, " (Penetracja: ", armor_penetration * 100, "%)")
		
		# 2. LOGIKA CIERNI (THORNS REFLECTION)
		# Upewniamy się, że to nie jest już odbity cios, oraz że sprawca żyje i nie bije sam siebie
		if not is_reflected_damage and is_instance_valid(source_entity) and source_entity != target:
			
			# Obliczamy rzeczywiste obrażenia, które weszły w ciało, aby obliczyć z nich procent cierni
			var effective_armor = float(stats.get_total_armor()) * (1.0 - armor_penetration)
			var effective_damage = max(1, damage_amount - int(effective_armor))
			
			# Sumujemy płaskie obrażenia zbroi i procent odbitego ciosu
			var reflected_dmg = stats.thorns_damage + int(float(effective_damage) * stats.thorns_percent)
			
			if reflected_dmg > 0:
				print("Ciernie! Odbijanie ", reflected_dmg, " DMG w ", source_entity.name)
				
				# Tworzymy zwrotny efekt obrażeń (Penetracja 0.0, flaga is_reflected = true)
				var thorn_effect = DamageEffect.new(reflected_dmg, 0.0, true)
				# Cel staje się strzelcem, bo to zbroja oddaje cios!
				thorn_effect.source_entity = target
				
				# Bezpieczne nałożenie efektu na pierwotnego napastnika
				if source_entity.has_method("receive_effect"):
					source_entity.receive_effect(thorn_effect)
				else:
					thorn_effect.apply_effect(source_entity)
					
		return true
	return false
