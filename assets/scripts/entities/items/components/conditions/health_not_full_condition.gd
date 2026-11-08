class_name HealthNotFullCondition
extends ItemCondition
## Sprawdza, czy postać jest ranna. Zwróci false (zablokuje użycie), jeśli ma pełne zdrowie.

const INJURED_REQUIREMENT_TEXT: String = "Tylko gdy ranny"

func check_condition(actor: Node2D, _item: ItemInstance) -> bool:
	# Sprawdzamy bezpiecznie, czy podmiot w ogóle posiada skrypt zdrowia
	if actor != null and actor.get("health_stats_script") != null:
		var stats = actor.health_stats_script
		# Jeśli zdrowie jest pełne lub wyższe od maksimum - blokujemy zużycie apteczki
		if stats.health >= stats.max_health:
			print("Mam pełne zdrowie! Nie mogę tego użyć.")
			return false 

	# W każdym innym wypadku (ranny, albo obiekt bez statystyk HP) pozwalamy na użycie
	return true

## Zwraca opis wymogu dla panelu informacji HUD (bez konieczności sprawdzania typu 'is' w UI).
func get_condition_description() -> String:
	if custom_condition_description != "":
		return custom_condition_description
	return INJURED_REQUIREMENT_TEXT
