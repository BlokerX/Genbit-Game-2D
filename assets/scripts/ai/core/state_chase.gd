extends AIState
class_name StateChase

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(delta: float) -> void:
	if blackboard.target == null or controller.perception == null:
		return
		
	var spider = controller.entity as NewEnemySpider
	if controller.perception.can_see_target(blackboard.target):
		blackboard.last_known_position = blackboard.target.global_position
		blackboard.has_last_known_position = true
		
		# Tymczasowo przypisane bezpośrednio tutaj (w następnym kroku przejmie to Nawigacja)
		if spider and spider.has_method("set_movement_target"):
			spider.set_movement_target(blackboard.last_known_position)
			
		var target_angle = spider.global_position.angle_to_point(blackboard.target.global_position)
		spider.rotation = lerp_angle(spider.rotation, target_angle, spider.rotationSpeed * delta)
		
		var distance = spider.global_position.distance_to(blackboard.target.global_position)
		
		# Używamy zmiennej z Pająka zamiast "sztywnego" 95.0
		blackboard.want_to_move = distance > spider.min_stopping_distance
	else:
		if blackboard.has_last_known_position:
			controller.state_machine.change_state("Search")
		else:
			controller.state_machine.change_state("Idle")
