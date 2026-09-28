extends Resource
class_name ObjectSpawnPool

@export var entries: Array[ObjectSpawnEntry] = []

func get_random_object_scene() -> PackedScene:
	if entries.is_empty(): return null
	var total_weight: float = 0.0
	for e in entries: if e and e.object_scene: total_weight += e.weight
	if total_weight <= 0.0: return null
	
	var roll = randf() * total_weight
	var current_weight: float = 0.0
	for e in entries:
		if e and e.object_scene:
			current_weight += e.weight
			if roll <= current_weight: return e.object_scene
	return null
