extends Node
class_name AICombatController

var controller: AIController

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller

func process_combat(delta: float) -> void:
	var entity = controller.entity
	var blackboard = controller.blackboard
	var stats = entity.interaction_and_attack_stats_script
	
	if not stats or blackboard.target == null:
		return
		
	# Odliczanie czasu do następnego ataku
	stats.interaction_cooldown_process(delta)
	
	# Proste sprawdzanie kolizji wręcz (dokładnie to, co robił Pająk)
	for i in entity.get_slide_collision_count():
		var collision = entity.get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Jeśli AI uderza w swój cel i ma gotowy cooldown
		if collider == blackboard.target and stats.can_attack():
			print("AI ", entity.name, " atakuje wręcz cel: ", collider.name)
			stats.execute_attack_on_target(entity, collider)
