extends AIState
class_name StateChase
## Stan aktywnego pościgu AI za celem (obsługuje utrzymywanie dystansu bojowego, kiting,
## zakaz dociskania gracza do ściany oraz obrót w stronę celu).

const RETREAT_TARGET_OFFSET_PX: float = 150.0
const ATTACK_RANGE_STOPPING_SAFETY_MARGIN_PX: float = 8.0

func enter() -> void:
	blackboard.want_to_move = true

func physics_process(delta: float) -> void:
	if not is_instance_valid(blackboard.target) or controller.perception == null:
		blackboard.target = null
		var fallback_state: String = "Search" if blackboard.has_last_known_position else "Idle"
		controller.state_machine.change_state(fallback_state)
		return

	var entity: CharacterEntity = controller.entity
	var profile: AIBehaviorProfile = controller.behavior_profile
	if profile == null or not is_instance_valid(entity):
		return

	if not controller.perception.can_see_target(blackboard.target):
		var lost_state: String = "Search" if blackboard.has_last_known_position else "Idle"
		controller.state_machine.change_state(lost_state)
		return

	blackboard.last_known_position = blackboard.target.global_position
	blackboard.has_last_known_position = true

	var edge_distance: float = CharacterEntity.get_edge_distance_between(entity, blackboard.target)
	blackboard.target_distance = edge_distance

	# --- 1. LOGIKA KITINGU (UCIECZKI STRZELCÓW) ---
	if profile.retreat_distance > 0.0 and edge_distance < profile.retreat_distance:
		blackboard.want_to_move = true
		var retreat_dir: Vector2 = blackboard.target.global_position.direction_to(entity.global_position)
		var retreat_pos: Vector2 = entity.global_position + (retreat_dir * RETREAT_TARGET_OFFSET_PX)
		if entity.has_method("set_movement_target"):
			entity.set_movement_target(retreat_pos)
	else:
		# --- 2. NORMALNY POŚCIG Z ZAKAZEM DOCISKANIA GRACZA DO ŚCIANY ---
		var effective_stop_dist: float = _get_effective_stopping_distance(entity, blackboard.target, profile)
		blackboard.want_to_move = edge_distance > effective_stop_dist

		if blackboard.want_to_move and entity.has_method("set_movement_target"):
			entity.set_movement_target(blackboard.last_known_position)

	if profile.can_rotate_to_target:
		var target_angle: float = entity.global_position.angle_to_point(blackboard.target.global_position)
		entity.rotation = lerp_angle(entity.rotation, target_angle, profile.rotation_speed * delta)

## Oblicza dystans zatrzymania z uwzględnieniem korytarza ucieczki pod ścianą oraz zasięgu ataku jednostki.
func _get_effective_stopping_distance(
	entity: CharacterEntity,
	target: CharacterEntity,
	profile: AIBehaviorProfile
) -> float:
	var required_margin: float = profile.player_personal_space_margin
	if profile.avoid_pinning_target_to_wall and CrowdCollisionController.is_target_backed_against_wall(entity, target):
		required_margin = maxf(required_margin, profile.wall_escape_corridor_distance)

	var desired_stop: float = maxf(profile.min_stopping_distance, required_margin)
	var stats: InteractionAndAttackStatsComponent = entity.interaction_and_attack_stats_script
	if stats != null:
		var max_attack_range: float = maxf(0.0, stats.get_total_range() - ATTACK_RANGE_STOPPING_SAFETY_MARGIN_PX)
		if max_attack_range > 0.0:
			desired_stop = minf(desired_stop, max_attack_range)
	return desired_stop
