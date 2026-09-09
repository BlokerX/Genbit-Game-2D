extends AIState
class_name StateChase

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(delta: float) -> void:
	if blackboard.target == null or controller.perception == null:
		return
		
	var entity = controller.entity
	var profile = controller.behavior_profile
	
	# Zabezpieczenie przed brakiem profilu
	if profile == null:
		return
		
	if controller.perception.can_see_target(blackboard.target):
		blackboard.last_known_position = blackboard.target.global_position
		blackboard.has_last_known_position = true
		
		if entity.has_method("set_movement_target"):
			entity.set_movement_target(blackboard.last_known_position)
			
		# TWOJA POPRAWKA: Pytamy profil, czy ten wróg w ogóle umie się obracać!
		if profile.can_rotate_to_target:
			var target_angle = entity.global_position.angle_to_point(blackboard.target.global_position)
			entity.rotation = lerp_angle(entity.rotation, target_angle, profile.rotation_speed * delta)
		
		var distance = entity.global_position.distance_to(blackboard.target.global_position)
		blackboard.want_to_move = distance > profile.min_stopping_distance
	else:
		if blackboard.has_last_known_position:
			controller.state_machine.change_state("Search")
		else:
			controller.state_machine.change_state("Idle")
