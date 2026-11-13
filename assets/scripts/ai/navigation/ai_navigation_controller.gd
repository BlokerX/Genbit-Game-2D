extends Node
class_name AINavigationController
## Kontroler nawigacji AI przekształcający ścieżkę z NavigationAgent2D i wektor unikania zagrożeń w ruch fizyczny.

const AVOIDANCE_THREAT_WEIGHT_MULTIPLIER: float = 2.0
const DEFAULT_FALLBACK_MOVE_SPEED: float = 150.0
const EVADE_WHILE_STOPPED_THREAT_THRESHOLD: float = 0.75
const MIN_AVOIDANCE_VECTOR_LEN_SQ: float = 0.05

var controller: AIController
var nav_agent: NavigationAgent2D

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	nav_agent = controller.entity.get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func process_navigation(delta: float) -> void:
	var entity: CharacterEntity = controller.entity
	var blackboard: AIBlackboard = controller.blackboard
	var profile: AIBehaviorProfile = controller.behavior_profile
	var is_casting: bool = controller.combat != null and controller.combat.is_casting_ability

	if not blackboard.want_to_move:
		# Jeśli jednostka stoi w miejscu (np. strzelec na dystansie ataku lub w stanie Idle),
		# ale nadlatuje w jej stronę pocisk/zagrożenie (wysoki threat_level), wykonuje uskok!
		var should_evade_in_place: bool = (
			not is_casting
			and profile != null
			and profile.intelligent_movement
			and blackboard.threat_level >= EVADE_WHILE_STOPPED_THREAT_THRESHOLD
			and blackboard.avoidance_vector.length_squared() >= MIN_AVOIDANCE_VECTOR_LEN_SQ
		)

		if should_evade_in_place:
			var evade_dir: Vector2 = blackboard.avoidance_vector.normalized()
			if entity.movement_universal_script:
				entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, evade_dir)
			else:
				entity.velocity = evade_dir * DEFAULT_FALLBACK_MOVE_SPEED

			if not profile.can_rotate_to_target:
				entity._update_sprite_direction(evade_dir)
			entity.move_and_slide()
		else:
			if entity.movement_universal_script:
				entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, Vector2.ZERO)
			else:
				# Jednostka bez MovementComponent musi również wyzerować prędkość po zatrzymaniu!
				entity.velocity = Vector2.ZERO
	else:
		if nav_agent:
			var next_pos: Vector2 = nav_agent.get_next_path_position()
			var direction: Vector2 = entity.global_position.direction_to(next_pos)

			# --- APLIKACJA THREAT AVOIDANCE (CONTEXT STEERING) ---
			if profile and profile.intelligent_movement and blackboard.avoidance_vector != Vector2.ZERO:
				var avoidance_weight: float = blackboard.threat_level * AVOIDANCE_THREAT_WEIGHT_MULTIPLIER
				direction = (direction + (blackboard.avoidance_vector * avoidance_weight)).normalized()

			if entity.movement_universal_script:
				entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, direction)
			else:
				entity.velocity = direction * DEFAULT_FALLBACK_MOVE_SPEED

			if profile and not profile.can_rotate_to_target:
				entity._update_sprite_direction(direction)
			entity.move_and_slide()
