extends Node
class_name AINavigationController
## Kontroler nawigacji AI przekształcający ścieżkę z NavigationAgent2D, unikanie zagrożeń,
## separację roju oraz zakaz dociskania gracza do ściany w płynny ruch fizyczny.

const AVOIDANCE_THREAT_WEIGHT_MULTIPLIER: float = 2.0
const DEFAULT_FALLBACK_MOVE_SPEED: float = 150.0
const EVADE_WHILE_STOPPED_THREAT_THRESHOLD: float = 0.75
const MIN_AVOIDANCE_VECTOR_LEN_SQ: float = 0.04

const SEPARATION_UPDATE_INTERVAL_SEC: float = 0.08
const MAX_SEPARATION_NEIGHBORS_CHECKED: int = 8
const STOPPED_RELIEF_SPEED_RATIO: float = 0.80
const STOPPED_SEPARATION_WEIGHT: float = 0.65
const MIN_RELIEF_TRIGGER_LEN_SQ: float = 0.02

var controller: AIController
var nav_agent: NavigationAgent2D

var _separation_timer: float = 0.0
var _cached_separation_vector: Vector2 = Vector2.ZERO

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	nav_agent = controller.entity.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	_separation_timer = randf_range(0.0, SEPARATION_UPDATE_INTERVAL_SEC)

func process_navigation(delta: float) -> void:
	if controller == null or not is_instance_valid(controller.entity):
		return

	var entity: CharacterEntity = controller.entity
	var blackboard: AIBlackboard = controller.blackboard
	var profile: AIBehaviorProfile = controller.behavior_profile
	var is_casting: bool = controller.combat != null and controller.combat.is_casting_ability

	if is_casting:
		_stop_entity_movement(entity, delta)
		return

	# Bezpieczna walidacja celu w Blackboardzie (chroni przed błędem 'previously freed')
	var valid_target: CharacterEntity = null
	if is_instance_valid(blackboard.target):
		valid_target = blackboard.target
	else:
		blackboard.target = null

	_update_crowd_separation_vector(delta, entity, profile)
	var crowd_relief_vec: Vector2 = _calculate_crowd_and_wall_relief(entity, valid_target, profile)

	if not blackboard.want_to_move:
		_process_stationary_navigation(entity, profile, blackboard, crowd_relief_vec, delta)
		return

	_process_active_path_navigation(entity, profile, blackboard, valid_target, crowd_relief_vec, delta)

## Obsługuje jednostkę, która zatrzymała pościg (np. osiągnęła dystans ataku): wykonuje uniki przed pociskami
## oraz cofa się / rozstępuje, jeśli dociska gracza do ściany lub blokuje wyjście z roju.
func _process_stationary_navigation(
	entity: CharacterEntity,
	profile: AIBehaviorProfile,
	blackboard: AIBlackboard,
	crowd_relief_vec: Vector2,
	delta: float
) -> void:
	var should_evade_projectile: bool = (
		profile != null
		and profile.intelligent_movement
		and blackboard.threat_level >= EVADE_WHILE_STOPPED_THREAT_THRESHOLD
		and blackboard.avoidance_vector.length_squared() >= MIN_AVOIDANCE_VECTOR_LEN_SQ
	)

	if should_evade_projectile:
		var evade_dir: Vector2 = (blackboard.avoidance_vector + crowd_relief_vec).normalized()
		_apply_entity_movement(entity, profile, delta, evade_dir, 1.0)
		return

	var total_stationary_relief: Vector2 = crowd_relief_vec + (_cached_separation_vector * STOPPED_SEPARATION_WEIGHT)
	if total_stationary_relief.length_squared() >= MIN_RELIEF_TRIGGER_LEN_SQ:
		_apply_entity_movement(entity, profile, delta, total_stationary_relief.normalized(), STOPPED_RELIEF_SPEED_RATIO)
		return

	_stop_entity_movement(entity, delta)

## Obsługuje jednostkę będącą w ruchu po ścieżce z uwzględnieniem zakazu dociskania gracza do ściany i separacji roju.
func _process_active_path_navigation(
	entity: CharacterEntity,
	profile: AIBehaviorProfile,
	blackboard: AIBlackboard,
	valid_target: CharacterEntity,
	crowd_relief_vec: Vector2,
	delta: float
) -> void:
	if nav_agent == null:
		return

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = entity.global_position.direction_to(next_pos)

	# Jeśli jednostka narusza już korytarz bezpieczeństwa gracza (np. pod ścianą),
	# wycinamy składową wektora pchającą w stronę gracza!
	if crowd_relief_vec != Vector2.ZERO and valid_target != null:
		var dir_to_target: Vector2 = entity.global_position.direction_to(valid_target.global_position)
		if direction.dot(dir_to_target) > 0.0:
			direction = direction.slide(dir_to_target)

	if profile != null and profile.intelligent_movement and blackboard.avoidance_vector != Vector2.ZERO:
		direction += blackboard.avoidance_vector * (blackboard.threat_level * AVOIDANCE_THREAT_WEIGHT_MULTIPLIER)

	if profile != null and profile.enable_crowd_separation and _cached_separation_vector != Vector2.ZERO:
		direction += _cached_separation_vector * profile.separation_weight

	if crowd_relief_vec != Vector2.ZERO:
		direction += crowd_relief_vec

	if direction.length_squared() <= 0.0001:
		_stop_entity_movement(entity, delta)
		return

	_apply_entity_movement(entity, profile, delta, direction.normalized(), 1.0)

## Łączy wektor zakazu dociskania gracza do ściany oraz wektor rozstępowania się roju przed idącym graczem.
func _calculate_crowd_and_wall_relief(
	entity: CharacterEntity,
	valid_target: Variant,
	profile: AIBehaviorProfile
) -> Vector2:
	if profile == null or not profile.avoid_pinning_target_to_wall or not is_instance_valid(valid_target):
		return Vector2.ZERO

	var wall_escape_vec: Vector2 = CrowdCollisionController.calculate_wall_escape_vector(
		entity,
		valid_target,
		profile.player_personal_space_margin,
		profile.wall_escape_corridor_distance
	)
	var swarm_part_vec: Vector2 = CrowdCollisionController.calculate_swarm_parting_vector_for_ai(
		entity,
		valid_target
	)
	return wall_escape_vec + swarm_part_vec

## Oblicza w interwale czasowym wektor separacji od pobliskich jednostek AI, zapobiegając zbijaniu się roju w jedną bryłę.
func _update_crowd_separation_vector(delta: float, entity: CharacterEntity, profile: AIBehaviorProfile) -> void:
	if profile == null or not profile.enable_crowd_separation or profile.separation_radius <= 0.0:
		_cached_separation_vector = Vector2.ZERO
		return

	_separation_timer -= delta
	if _separation_timer > 0.0:
		return
	_separation_timer = SEPARATION_UPDATE_INTERVAL_SEC

	var my_pos: Vector2 = entity.global_position
	var my_rad: float = entity.get_effective_combat_radius()
	var sep_accum: Vector2 = Vector2.ZERO
	var neighbors_counted: int = 0

	for other in PerceptionComponent.get_shared_characters(get_tree()):
		if not is_instance_valid(other) or other == entity or other.is_queued_for_deletion():
			continue
		if other.get("is_dead") == true or other.is_in_group("Player") or not (other is Node2D):
			continue

		var other_2d: Node2D = other as Node2D
		var desired_gap: float = my_rad + CharacterEntity.get_effective_radius_of(other_2d) + profile.separation_radius
		var dist_sq: float = my_pos.distance_squared_to(other_2d.global_position)
		if dist_sq >= desired_gap * desired_gap:
			continue

		var dist: float = sqrt(dist_sq)
		var push_dir: Vector2 = (
			(my_pos - other_2d.global_position) / dist
			if dist > 0.01
			else Vector2.RIGHT.rotated(float(entity.get_instance_id() % 360) * (TAU / 360.0))
		)
		var overlap_ratio: float = clampf(1.0 - (dist / maxf(1.0, desired_gap)), 0.0, 1.0)
		sep_accum += push_dir * overlap_ratio
		neighbors_counted += 1
		if neighbors_counted >= MAX_SEPARATION_NEIGHBORS_CHECKED:
			break

	_cached_separation_vector = sep_accum

func _apply_entity_movement(
	entity: CharacterEntity,
	profile: AIBehaviorProfile,
	delta: float,
	direction: Vector2,
	speed_scale: float = 1.0
) -> void:
	if entity.movement_universal_script:
		entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, direction * speed_scale)
	else:
		entity.velocity = direction * (DEFAULT_FALLBACK_MOVE_SPEED * speed_scale)

	if profile and not profile.can_rotate_to_target:
		entity._update_sprite_direction(direction)
	entity.move_and_slide()

func _stop_entity_movement(entity: CharacterEntity, delta: float) -> void:
	if entity.movement_universal_script:
		entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, Vector2.ZERO)
	else:
		entity.velocity = Vector2.ZERO
