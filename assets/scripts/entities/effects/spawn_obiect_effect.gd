extends Effect
class_name SpawnObjectEffect

@export_category("Spawn Settings")
## Scena, która ma zostać postawiona
@export var scene_to_spawn : PackedScene
## Przesunięcie względem celu (np. żeby obiekt nie pojawiał się wewnątrz gracza)
@export var spawn_offset : Vector2 = Vector2.ZERO

func apply_effect(target : Node2D) -> bool:
	if scene_to_spawn == null:
		push_error("SpawnObjectEffect: Brak przypisanej sceny!")
		return false
		
	var world = target.get_parent()
	if not world:
		return false
		
	var instance = scene_to_spawn.instantiate()
	
	# Ustawiamy pozycję (pozycja gracza + przesunięcie)
	if "global_position" in instance:
		instance.global_position = target.global_position + spawn_offset
		
	world.add_child(instance)
	return true
