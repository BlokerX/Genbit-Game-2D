extends Resource
class_name EnemySpawnPool

@export var entries: Array[EnemySpawnEntry] = []

## Zwraca losową scenę przeciwnika na podstawie wag przypisanych we wpisach EnemySpawnEntry.
func get_random_enemy_scene() -> PackedScene:
	var chosen_entry: EnemySpawnEntry = ItemLootPool.pick_weighted_entry(entries, &"enemy_scene") as EnemySpawnEntry
	return chosen_entry.enemy_scene if chosen_entry != null else null
