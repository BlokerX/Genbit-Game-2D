extends Node
class_name PerceptionComponent

@export var detection_distance: float = 600.0
@export var los_ray: RayCast2D

var controller: AIController

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	
	# AUTO-RESOLVE: Szuka promienia wewnątrz Pająka
	if not los_ray and controller.entity:
		los_ray = controller.entity.get_node_or_null("LineOfSight")

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
			
	return false
