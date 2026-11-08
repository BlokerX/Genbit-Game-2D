extends Resource
class_name ItemLootPool

@export var entries: Array[ItemLootEntry] = []

## Zwraca JEDEN losowy wpis (ItemLootEntry), typując go na podstawie wagi (Koło Fortuny).
func get_random_entry() -> ItemLootEntry:
	return pick_weighted_entry(entries, &"item_data") as ItemLootEntry

## Uniwersalny algorytm ważonego losowania (Koło Fortuny) współdzielony przez wszystkie pule spawnu (DRY).
static func pick_weighted_entry(pool_entries: Array, required_property: StringName) -> Resource:
	if pool_entries.is_empty():
		return null

	var total_weight: float = 0.0
	for entry in pool_entries:
		if entry != null and entry.get(required_property) != null:
			var w: float = float(entry.get("weight")) if "weight" in entry else 0.0
			if w > 0.0:
				total_weight += w

	if total_weight <= 0.0:
		return null

	var roll: float = randf() * total_weight
	var current_weight: float = 0.0

	for entry in pool_entries:
		if entry != null and entry.get(required_property) != null:
			var w: float = float(entry.get("weight")) if "weight" in entry else 0.0
			if w > 0.0:
				current_weight += w
				if roll <= current_weight:
					return entry

	return null
