extends AIState
class_name StateSearch

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(_delta: float) -> void:
	var entity = controller.entity
	var profile = controller.behavior_profile
	
	if profile == null: return
		
	# Jeśli w trakcie szukania kogoś zauważymy -> Wracamy do pościgu!
	if blackboard.target != null and controller.perception != null:
		if controller.perception.can_see_target(blackboard.target):
			controller.state_machine.change_state("Chase")
			return
		
	if entity.get("navigation_agent") and entity.navigation_agent.is_navigation_finished():
		blackboard.has_last_known_position = false
		if entity.get("wanderTimer") != null:
			entity.wanderTimer = randf_range(profile.wander_interval_min, profile.wander_interval_max)
		controller.state_machine.change_state("Idle")
