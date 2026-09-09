extends Node
class_name PerceptionComponent

@export var detection_distance: float = 600.0
@export var los_ray: RayCast2D
var controller: AIController

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	if not los_ray and controller.entity:
		los_ray = controller.entity.get_node_or_null("LineOfSight")

func process_perception(_delta: float) -> void:
	var entity = controller.entity
	var blackboard = controller.blackboard
	
	var my_faction = entity.faction_component
	if not my_faction:
		my_faction = entity.get_node_or_null("FactionComponent")
		
	if not my_faction:
		return 
		
	var best_target: CharacterEntity = null
	var best_distance: float = detection_distance
	
	for potential_target in get_tree().get_nodes_in_group("Character"):
		if potential_target == entity: 
			continue
			
		if my_faction.get_disposition_toward(potential_target) == FactionComponent.Disposition.HOSTILE:
			var dist = entity.global_position.distance_to(potential_target.global_position)
			if dist < best_distance and can_see_target(potential_target):
				best_distance = dist
				best_target = potential_target
				
	blackboard.target = best_target

func can_see_target(target: Node2D) -> bool:
	if not target or not controller or not controller.entity:
		return false
		
	var entity = controller.entity
	if entity.global_position.distance_to(target.global_position) > detection_distance:
		return false
		
	if los_ray:
		los_ray.target_position = entity.to_local(target.global_position)
		los_ray.force_raycast_update()
		if los_ray.is_colliding():
			return los_ray.get_collider() == target
	else:
		# KULOODPORNY FALLBACK: Używamy wirtualnego promienia fizyki, jeśli węzeł zniknął
		var space_state = entity.get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(entity.global_position, target.global_position)
		query.exclude = [entity.get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			return result.collider == target
			
	return false
