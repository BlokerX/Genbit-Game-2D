extends AIState
class_name StateSearch

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(_delta: float) -> void:
	if blackboard.target == null or controller.perception == null:
		return
		
	var entity = controller.entity
	if controller.perception.can_see_target(blackboard.target):
		controller.state_machine.change_state("Chase")
		
	elif entity.get("navigation_agent") and entity.navigation_agent.is_navigation_finished():
		blackboard.has_last_known_position = false
		
		# W przyszłości ten timer trafi do osobnego profilu zachowań
		if entity.get("wanderTimer") != null:
			entity.wanderTimer = randf_range(1.0, 6.0)
			
		controller.state_machine.change_state("Idle")
