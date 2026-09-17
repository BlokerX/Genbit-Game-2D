extends AIState
class_name StateIdle

func enter() -> void:
	blackboard.want_to_move = false

func physics_process(_delta: float) -> void:
	if blackboard.target == null or controller.perception == null:
		return
		
	if controller.perception.can_see_target(blackboard.target):
		controller.state_machine.change_state("Chase")
