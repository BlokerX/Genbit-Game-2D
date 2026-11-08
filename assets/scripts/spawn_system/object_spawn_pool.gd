extends Resource
class_name ObjectSpawnPool

@export var entries: Array[ObjectSpawnEntry] = []

## Zwraca losową scenę obiektu na podstawie wag przypisanych we wpisach ObjectSpawnEntry.
func get_random_object_scene() -> PackedScene:
	var chosen_entry: ObjectSpawnEntry = ItemLootPool.pick_weighted_entry(entries, &"object_scene") as ObjectSpawnEntry
	return chosen_entry.object_scene if chosen_entry != null else null
