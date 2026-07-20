extends Node
class_name ItemThrowerComponent

## Sygnał do powiadamiania menedżera poziomu o konieczności umieszczenia węzła na mapie
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")

@export_group("Throw Settings")
@export var max_throw_range: float = 150.0
@export var min_throw_force: float = 50.0
@export var pad_throw_force_min: float = 200.0
@export var pad_throw_force_max: float = 300.0
@export var drop_push_force: float = 20.0
@export var throw_force_multiplier: float = 3.0

## Główna funkcja wywoływana, gdy ekwipunek potwierdzi wyrzucenie przedmiotu
func handle_item_drop(thrower: Node2D, dropped_instance: ItemInstance, is_thrown: bool, is_using_mouse: bool, pad_aim_direction: Vector2) -> void:
	if item_pickup_scene == null:
		push_error("Błąd: Brak przypisanej sceny item_pickup_scene w ItemThrowerComponent!")
		return
	
	var drop = item_pickup_scene.instantiate()
	
	# Bezpieczne przypisanie paczki z przedmiotem do obiektu leżącego na ziemi
	if "item" in drop:
		drop.item = dropped_instance 
	
	# Zgłaszamy potrzebę zespawnowania obiektu w świecie
	entity_spawn_requested.emit(drop, thrower.global_position)
	
	var drop_direction = Vector2.ZERO
	var drop_force = 0.0
	
	if is_thrown:
		if is_using_mouse:
			# --- WYRZUT MYSZKĄ ---
			var mouse_global_pos = thrower.get_global_mouse_position()
			var dist_to_mouse = thrower.global_position.distance_to(mouse_global_pos)
			
			var aim_direction = thrower.global_position.direction_to(mouse_global_pos)
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2.DOWN
			
			var actual_throw_distance = min(dist_to_mouse, max_throw_range)
			drop_force = actual_throw_distance * throw_force_multiplier
			
			if drop_force < min_throw_force:
				drop_force = min_throw_force
			
			var spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
			drop_direction = (aim_direction + spread).normalized()
			
		else:
			# --- WYRZUT PADEM / KLAWIATURĄ ---
			var aim_direction = pad_aim_direction.normalized()
			
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			
			var spread = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			drop_direction = (aim_direction + spread).normalized()
			drop_force = randf_range(pad_throw_force_min, pad_throw_force_max)
	else:
		# --- DELIKATNE UPUSZCZENIE (np. z craftingu) ---
		drop_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		drop_force = drop_push_force
	
	# Jeżeli nasz upuszczony przedmiot wykorzystuje silnik fizyczny
	if drop is RigidBody2D:
		drop.apply_central_impulse(drop_direction * drop_force)
