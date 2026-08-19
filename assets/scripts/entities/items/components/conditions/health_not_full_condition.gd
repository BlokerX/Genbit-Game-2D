class_name HealthNotFullCondition
extends ItemCondition

## Sprawdza, czy gracz jest ranny. Zwróci false (zablokuje użycie), jeśli ma pełne zdrowie.
func check_condition(actor: Node2D, _item: ItemInstance) -> bool:
	# Sprawdzamy bezpiecznie, czy podmiot w ogóle posiada skrypt zdrowia
	if actor.get("health_stats_script") != null:
		var stats = actor.health_stats_script
		
		# Jeśli zdrowie jest pełne lub wyższe od maksimum - blokujemy
		if stats.health >= stats.max_health:
			print("Mam pełne zdrowie! Nie mogę tego użyć.")
			return false 
			
	# W każdym innym wypadku (ranny, albo to nie jest gracz) pozwalamy na użycie
	return true
