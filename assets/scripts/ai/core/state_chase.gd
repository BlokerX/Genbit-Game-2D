extends AIState
class_name StateChase

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(delta: float) -> void:
	# Jeśli zgubiliśmy cel z oczu, natychmiast wracamy do szukania!
	if blackboard.target == null or controller.perception == null:
		if blackboard.has_last_known_position:
			controller.state_machine.change_state("Search")
		else:
			controller.state_machine.change_state("Idle")
		return
		
	var entity = controller.entity
	var profile = controller.behavior_profile
	if profile == null: return
	
	if controller.perception.can_see_target(blackboard.target):
		blackboard.last_known_position = blackboard.target.global_position
		blackboard.has_last_known_position = true
		
		var distance = entity.global_position.distance_to(blackboard.target.global_position)
		
		# --- LOGIKA KITINGU (UCIECZKI) ---
		if "retreat_distance" in profile and profile.retreat_distance > 0.0 and distance < profile.retreat_distance:
			# Wróg jest zbyt blisko! Zaczynamy uciekać.
			blackboard.want_to_move = true
			# Zamiast kierunku "do gracza", bierzemy wektor OD gracza W STRONĘ przeciwnika
			var retreat_dir = blackboard.target.global_position.direction_to(entity.global_position)
			# każemy mu biec do punktu za swoimi plecami
			var retreat_pos = entity.global_position + (retreat_dir * 150.0) 
			
			if entity.has_method("set_movement_target"):
				entity.set_movement_target(retreat_pos)
		else:
			# --- NORMALNY POŚCIG LUB ZATRZYMANIE DO STRZAŁU ---
			blackboard.want_to_move = distance > profile.min_stopping_distance
			if blackboard.want_to_move:
				if entity.has_method("set_movement_target"):
					entity.set_movement_target(blackboard.last_known_position)
		
		# Obrót w stronę gracza (nawet jeśli uciekamy, lufa jest zwrócona na gracza!)
		if profile.can_rotate_to_target:
			var target_angle = entity.global_position.angle_to_point(blackboard.target.global_position)
			entity.rotation = lerp_angle(entity.rotation, target_angle, profile.rotation_speed * delta)
			
	else:
		if blackboard.has_last_known_position:
			controller.state_machine.change_state("Search")
		else:
			controller.state_machine.change_state("Idle")
