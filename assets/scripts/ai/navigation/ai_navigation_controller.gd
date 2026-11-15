extends Node
class_name AINavigationController
## Kontroler nawigacji AI przekształcający ścieżkę z NavigationAgent2D, unikanie zagrożeń,
## separację pierścieni roju oraz odblokowywanie gracza pod ścianą w płynny ruch fizyczny.

const AVOIDANCE_THREAT_WEIGHT_MULTIPLIER: float = 2.0
const DEFAULT_FALLBACK_MOVE_SPEED: float = 150.0
const EVADE_WHILE_STOPPED_THREAT_THRESHOLD: float = 0.75
const MIN_AVOIDANCE_VECTOR_LEN_SQ: float = 0.04

const SEPARATION_UPDATE_INTERVAL_SEC: float = 0.06
const MAX_SEPARATION_NEIGHBORS_CHECKED: int = 12
const WALL_RELIEF_SPEED_RATIO: float = 0.80
const MIN_RELIEF_TRIGGER_LEN_SQ: float = 0.02
## Próg iloczynu skalarnego określający, że inny sojusznik stoi bezpośrednio przed nami na linii do gracza.
const INNER_RING_ALLY_BLOCK_DOT_THRESHOLD: float = 0.45

var controller: AIController
var nav_agent: NavigationAgent2D

var _separation_timer: float = 0.0
var _cached_separation_vector: Vector2 = Vector2.ZERO
var _is_blocked_by_inner_ally: bool = false

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

	var valid_target: CharacterEntity = null
	if is_instance_valid(blackboard.target):
		valid_target = blackboard.target
	else:
		blackboard.target = null

	_update_crowd_separation_vector(delta, entity, valid_target, profile)
	var wall_relief_vec: Vector2 = _calculate_wall_relief(entity, valid_target, profile)

	if not blackboard.want_to_move:
		_process_stationary_navigation(entity, profile, blackboard, wall_relief_vec, delta)
		return

	_process_active_path_navigation(entity, profile, blackboard, valid_target, wall_relief_vec, delta)

## Sprawdza, czy gracz w tej klatce fizycznie napiera na tę jednostkę w zwarciu.
func _is_being_pushed_by_player_contact(entity: CharacterEntity) -> bool:
	if not entity.has_meta("crowd_contact_yield_until_msec"):
		return false
	return Time.get_ticks_msec() <= int(entity.get_meta("crowd_contact_yield_until_msec"))

func _process_stationary_navigation(
	entity: CharacterEntity,
	profile: AIBehaviorProfile,
	blackboard: AIBlackboard,
	wall_relief_vec: Vector2,
	delta: float
) -> void:
	var should_evade_projectile: bool = (
		profile != null
		and profile.intelligent_movement
		and blackboard.threat_level >= EVADE_WHILE_STOPPED_THREAT_THRESHOLD
		and blackboard.avoidance_vector.length_squared() >= MIN_AVOIDANCE_VECTOR_LEN_SQ
	)

	if should_evade_projectile:
		var evade_dir: Vector2 = (blackboard.avoidance_vector + wall_relief_vec).normalized()
		_apply_entity_movement(entity, profile, delta, evade_dir, 1.0)
		return

	# Na otwartym polu (gdy wall_relief_vec == ZERO) jednostka stoi twardo i jest styczna z graczem (nie ucieka!).
	# Ruch odblokowujący wykonuje wyłącznie wtedy, gdy gracz pod ścianą aktywnie próbuje wyjść z narożnika.
	if wall_relief_vec.length_squared() >= MIN_RELIEF_TRIGGER_LEN_SQ:
		_apply_entity_movement(entity, profile, delta, wall_relief_vec.normalized(), WALL_RELIEF_SPEED_RATIO)
		return

	_stop_entity_movement(entity, delta)

func _process_active_path_navigation(
	entity: CharacterEntity,
	profile: AIBehaviorProfile,
	blackboard: AIBlackboard,
	valid_target: CharacterEntity,
	wall_relief_vec: Vector2,
	delta: float
) -> void:
	if nav_agent == null:
		return

	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = entity.global_position.direction_to(next_pos)
	var is_pushed_in_contact: bool = _is_being_pushed_by_player_contact(entity)

	# Jeśli jednostka jest w 2./3. rzędzie za sojusznikiem (_is_blocked_by_inner_ally),
	# lub gracz właśnie przepycha się przez nią w kontakcie (is_pushed_in_contact),
	# wycinamy składową parcia w głąb gracza, pozwalając na ruch styczny bez uciekania!
	if (wall_relief_vec != Vector2.ZERO or _is_blocked_by_inner_ally or is_pushed_in_contact) and valid_target != null:
		var dir_to_target: Vector2 = entity.global_position.direction_to(valid_target.global_position)
		if direction.dot(dir_to_target) > 0.0:
			direction = direction.slide(dir_to_target)

	if profile != null and profile.intelligent_movement and blackboard.avoidance_vector != Vector2.ZERO:
		direction += blackboard.avoidance_vector * (blackboard.threat_level * AVOIDANCE_THREAT_WEIGHT_MULTIPLIER)

	if profile != null and profile.enable_crowd_separation and _cached_separation_vector != Vector2.ZERO:
		var sep_vec: Vector2 = _cached_separation_vector * profile.separation_weight
		# Jeśli jednostka jest w kontakcie z graczem, separacja od innych mobów nie może spychać jej na gracza!
		if valid_target != null:
			var dir_to_target: Vector2 = entity.global_position.direction_to(valid_target.global_position)
			if sep_vec.dot(dir_to_target) > 0.0 and CharacterEntity.get_edge_distance_between(entity, valid_target) <= 6.0:
				sep_vec = sep_vec.slide(dir_to_target)
		direction += sep_vec

	if wall_relief_vec != Vector2.ZERO:
		direction += wall_relief_vec

	if direction.length_squared() <= 0.0001:
		_stop_entity_movement(entity, delta)
		return

	_apply_entity_movement(entity, profile, delta, direction.normalized(), 1.0)

func _calculate_wall_relief(
	entity: CharacterEntity,
	valid_target: Variant,
	profile: AIBehaviorProfile
) -> Vector2:
	if profile == null or not profile.avoid_pinning_target_to_wall or not is_instance_valid(valid_target):
		return Vector2.ZERO

	return CrowdCollisionController.calculate_wall_escape_vector(
		entity,
		valid_target,
		profile.wall_escape_corridor_distance,
		profile.wall_pin_detection_distance
	)

func _update_crowd_separation_vector(
	delta: float,
	entity: CharacterEntity,
	valid_target: Variant,
	profile: AIBehaviorProfile
) -> void:
	if profile == null or not profile.enable_crowd_separation or profile.separation_radius <= 0.0:
		_cached_separation_vector = Vector2.ZERO
		_is_blocked_by_inner_ally = false
		return

	_separation_timer -= delta
	if _separation_timer > 0.0:
		return
	_separation_timer = SEPARATION_UPDATE_INTERVAL_SEC

	var my_pos: Vector2 = entity.global_position
	var my_rad: float = entity.get_effective_combat_radius()
	var has_target: bool = is_instance_valid(valid_target) and (valid_target is Node2D)
	var target_pos: Vector2 = (valid_target as Node2D).global_position if has_target else Vector2.ZERO
	var my_dist_to_target_sq: float = my_pos.distance_squared_to(target_pos) if has_target else INF
	var dir_to_target: Vector2 = my_pos.direction_to(target_pos) if has_target else Vector2.ZERO

	var sep_accum: Vector2 = Vector2.ZERO
	var blocked_in_front: bool = false
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
		var dir_to_other: Vector2 = (
			(other_2d.global_position - my_pos) / dist
			if dist > 0.01
			else Vector2.RIGHT.rotated(float(entity.get_instance_id() % 360) * (TAU / 360.0))
		)

		# Sąsiad blokuje nas od przodu TYLKO wtedy, gdy faktycznie znajduje się bliżej gracza niż my!
		if has_target and dir_to_target.dot(dir_to_other) >= INNER_RING_ALLY_BLOCK_DOT_THRESHOLD:
			if other_2d.global_position.distance_squared_to(target_pos) < my_dist_to_target_sq:
				blocked_in_front = true

		var push_away_dir: Vector2 = -dir_to_other
		var overlap_ratio: float = clampf(1.0 - (dist / maxf(1.0, desired_gap)), 0.15, 1.0)
		sep_accum += push_away_dir * overlap_ratio
		neighbors_counted += 1
		if neighbors_counted >= MAX_SEPARATION_NEIGHBORS_CHECKED:
			break

	_cached_separation_vector = sep_accum
	_is_blocked_by_inner_ally = blocked_in_front

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
