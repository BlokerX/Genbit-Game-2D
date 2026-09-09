extends Node
class_name AINavigationController

var controller: AIController
var nav_agent: NavigationAgent2D

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	# Szuka agenta w postaci
	nav_agent = controller.entity.get_node_or_null("NavigationAgent2D")

func process_navigation(delta: float) -> void:
	var entity = controller.entity
	var blackboard = controller.blackboard
	var profile = controller.behavior_profile
	
	if not blackboard.want_to_move:
		if entity.movement_universal_script:
			entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, Vector2.ZERO)
	else:
		if nav_agent:
			var next_pos = nav_agent.get_next_path_position()
			var direction = entity.global_position.direction_to(next_pos)
			
			if entity.movement_universal_script:
				entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, direction)
			else:
				entity.velocity = direction * 150.0
				
			# --- ROZWIĄZANIE TWOJEGO PROBLEMU Z ANIMACJĄ ---
			if profile and not profile.can_rotate_to_target:
				# Jeśli wróg się nie obraca jak wskazówka zegara, odpalamy animację klatkową!
				entity._update_sprite_direction(direction)
				
	entity.move_and_slide()
