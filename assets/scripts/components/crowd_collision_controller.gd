class_name CrowdCollisionController
extends RefCounted
## Dedykowany kontroler fizyki tłumu i ochrony przed przygwożdżeniem gracza do ściany (SOLID - SRP).
## Pozwala na pełną styczność z wrogami na otwartej przestrzeni (brak uciekania na dystans),
## uruchamiając łańcuchowe przepychanie roju w bezpośrednim styku oraz odblokowanie narożników pod ścianą wg AIBehaviorProfile.

# --- STAŁE FIZYKI TŁUMU I ANTY-DOCISKU DO ŚCIANY (Brak magicznych liczb) ---
## Maska warstw fizyki dla ścian/lawy (bit 1) oraz postawionych obiektów (bit 32).
const WALL_AND_OBSTACLES_MASK: int = 33
## Domyślna odległość sondowania ściany za plecami gracza (jeśli profil AI nie określa własnej).
const DEFAULT_WALL_BEHIND_CHECK_DISTANCE_PX: float = 60.0
## Maksymalny dystans krawędziowy bezpośredniego styku gracza z 1. rzędem wrogów na otwartym polu (styczność fizyczna!).
const DIRECT_CONTACT_MARGIN_PX: float = 2.5
## Domyślny korytarz ucieczki pod ścianą (jeśli profil AI nie określa własnego).
const DEFAULT_WALL_ESCAPE_CORRIDOR_PX: float = 65.0
## Prędkość boczno-stycznego przesuwania dotykanej jednostki podczas napierania gracza (w pikselach na sekundę).
const CONTACT_PARTING_SPEED_PX: float = 230.0
## Waga składowej stycznej (opływanie gracza na lewo i prawo w kontakcie).
const PARTING_TANGENTIAL_WEIGHT: float = 1.75
## Waga składowej promieniowej (delikatne wypchnięcie przed krawędź kolidera gracza).
const PARTING_RADIAL_WEIGHT: float = 0.45
## Maksymalna głębokość rekurencji przy łańcuchowym przepychaniu kolejnych stykających się rzędów w tłumie.
const MAX_CHAIN_PUSH_DEPTH: int = 6
## Współczynnik zachowania siły przekazywanej na kolejny stykający się rząd w łańcuchu kolizji.
const CHAIN_PUSH_ATTENUATION: float = 0.92
## Czas (w milisekundach), przez który przepychany wróg nie napiera z powrotem w głąb gracza.
const CONTACT_YIELD_HOLD_MSEC: int = 110
## Minimalny mnożnik podatności na pchnięcie, poniżej którego jednostka jest nieprzesuwalna.
const MIN_PUSHABLE_MULTIPLIER: float = 0.02
## Minimalny kwadrat długości wektora ruchu uznawany za istotne przesunięcie.
const MIN_MOTION_LEN_SQ: float = 0.005
## Minimalny iloczyn skalarny oznaczający, że gracz naciska klawisz ruchu w stronę danej jednostki AI.
const PLAYER_PRESSING_INTO_AI_DOT_MIN: float = 0.10
## Mnożnik siły zejścia w bok dla wroga/bossa, gdy gracz próbuje wyjść z narożnika pod ścianą.
const WALL_ESCAPE_TANGENT_WEIGHT: float = 1.85

## Wywoływane w pętli fizyki gracza przed move_and_slide().
func process_player_crowd_interaction(
	player: CharacterEntity,
	desired_input_dir: Vector2,
	delta: float
) -> void:
	if not is_instance_valid(player) or player.is_dead or player.is_respawning:
		return

	player.set_meta("crowd_desired_input_dir", desired_input_dir)
	if desired_input_dir.length_squared() <= 0.001:
		return

	var tree: SceneTree = player.get_tree()
	if tree == null:
		return

	var move_dir: Vector2 = desired_input_dir.normalized()
	var player_pos: Vector2 = player.global_position
	var now_msec: int = Time.get_ticks_msec()

	for node in PerceptionComponent.get_shared_characters(tree):
		if not is_instance_valid(node) or node == player or node.is_queued_for_deletion():
			continue
		if not (node is AICharacterEntity):
			continue
		var ai_entity: AICharacterEntity = node as AICharacterEntity
		if ai_entity.is_dead:
			continue

		var edge_dist: float = CharacterEntity.get_edge_distance_between(player, ai_entity)
		if edge_dist > DIRECT_CONTACT_MARGIN_PX:
			continue

		var push_mult: float = _get_effective_push_multiplier_for_context(player, ai_entity)
		if push_mult < MIN_PUSHABLE_MULTIPLIER:
			continue

		var center_dist: float = player_pos.distance_to(ai_entity.global_position)
		var to_ai: Vector2 = (ai_entity.global_position - player_pos) / maxf(0.001, center_dist)
		var forward_dot: float = to_ai.dot(move_dir)

		if forward_dot < PLAYER_PRESSING_INTO_AI_DOT_MIN:
			continue

		_slide_tangent_ai_with_chain(
			player,
			ai_entity,
			move_dir,
			to_ai,
			push_mult,
			CONTACT_PARTING_SPEED_PX,
			now_msec,
			delta
		)

## Wywoływane przy fizycznym zderzeniu w move_and_slide(): przesuwa stycznie dotkniętego moba i łańcuchowo rząd za nim.
func push_blocking_ai_chain(
	player: CharacterEntity,
	first_blocker: AICharacterEntity,
	collision_normal: Vector2,
	desired_input_dir: Vector2,
	push_speed_px: float,
	delta: float
) -> void:
	if not is_instance_valid(player) or not is_instance_valid(first_blocker) or first_blocker.is_dead:
		return

	var push_mult: float = _get_effective_push_multiplier_for_context(player, first_blocker)
	if push_mult < MIN_PUSHABLE_MULTIPLIER:
		return

	var move_dir: Vector2 = (
		desired_input_dir.normalized()
		if desired_input_dir.length_squared() > 0.001
		else -collision_normal
	)
	_slide_tangent_ai_with_chain(
		player,
		first_blocker,
		move_dir,
		-collision_normal,
		push_mult,
		push_speed_px,
		Time.get_ticks_msec(),
		delta
	)

## Zwraca podatność jednostki AI na przesunięcie: na otwartym polu bossowie mają 0.0 (stoją jak czołg),
## ale gdy gracz jest przyciśnięty plecami do ściany/lawy, uwzględnia wall_pin_push_allowance z AIBehaviorProfile!
static func _get_effective_push_multiplier_for_context(
	player: CharacterEntity,
	ai_entity: AICharacterEntity
) -> float:
	var base_mult: float = ai_entity.get_crowd_push_multiplier()
	var profile: AIBehaviorProfile = _get_ai_profile(ai_entity)
	if profile == null or not profile.avoid_pinning_target_to_wall:
		return base_mult

	if base_mult >= profile.wall_pin_push_allowance:
		return base_mult

	if is_target_backed_against_wall(ai_entity, player, profile.wall_pin_detection_distance):
		return maxf(base_mult, profile.wall_pin_push_allowance)

	return base_mult

static func _get_ai_profile(entity: CharacterEntity) -> AIBehaviorProfile:
	if not is_instance_valid(entity):
		return null
	var ai_ctrl: Node = entity.get_node_or_null("AIController")
	if ai_ctrl != null and ai_ctrl.get("behavior_profile") is AIBehaviorProfile:
		return ai_ctrl.behavior_profile as AIBehaviorProfile
	return null

func _slide_tangent_ai_with_chain(
	player: CharacterEntity,
	ai_body: AICharacterEntity,
	player_move_dir: Vector2,
	radial_from_player: Vector2,
	push_mult: float,
	speed_px: float,
	now_msec: int,
	delta: float
) -> void:
	var rel_pos: Vector2 = ai_body.global_position - player.global_position
	var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
	var lateral_offset: float = rel_pos.dot(right_normal)
	var side_sign: float = _resolve_consistent_parting_side(ai_body, lateral_offset)

	var lateral_dir: Vector2 = right_normal * side_sign
	var slide_dir: Vector2 = (
		(lateral_dir * PARTING_TANGENTIAL_WEIGHT) + (radial_from_player * PARTING_RADIAL_WEIGHT)
	).normalized()

	ai_body.set_meta("crowd_contact_yield_until_msec", now_msec + CONTACT_YIELD_HOLD_MSEC)

	var step_motion: Vector2 = slide_dir * (speed_px * push_mult * delta)
	var visited: Array[int] = [player.get_instance_id()]
	_move_ai_with_chain_push(ai_body, step_motion, 0, visited, now_msec)

func _move_ai_with_chain_push(
	ai_body: AICharacterEntity,
	motion: Vector2,
	depth: int,
	visited_ids: Array[int],
	now_msec: int
) -> void:
	if depth > MAX_CHAIN_PUSH_DEPTH or motion.length_squared() < MIN_MOTION_LEN_SQ:
		return
	if not is_instance_valid(ai_body) or ai_body.is_dead:
		return

	var my_id: int = ai_body.get_instance_id()
	if visited_ids.has(my_id):
		return
	visited_ids.append(my_id)

	var col: KinematicCollision2D = ai_body.move_and_collide(motion)
	if col == null:
		return

	var remainder: Vector2 = col.get_remainder()
	if remainder.length_squared() < MIN_MOTION_LEN_SQ:
		return

	var collider: Object = col.get_collider()
	if is_instance_valid(collider) and collider is AICharacterEntity:
		var blocker_ai: AICharacterEntity = collider as AICharacterEntity
		var blocker_mult: float = blocker_ai.get_crowd_push_multiplier()
		if not blocker_ai.is_dead and blocker_mult >= MIN_PUSHABLE_MULTIPLIER:
			var push_normal: Vector2 = -col.get_normal()
			var chain_dir: Vector2 = (push_normal + motion.normalized()).normalized()
			var transferred_motion: Vector2 = chain_dir * (remainder.length() * CHAIN_PUSH_ATTENUATION * blocker_mult)

			blocker_ai.set_meta("crowd_contact_yield_until_msec", now_msec + CONTACT_YIELD_HOLD_MSEC)
			_move_ai_with_chain_push(blocker_ai, transferred_motion, depth + 1, visited_ids, now_msec)

			var second_col: KinematicCollision2D = ai_body.move_and_collide(remainder)
			if second_col != null:
				var slide_after: Vector2 = second_col.get_remainder().slide(second_col.get_normal())
				if slide_after.length_squared() >= MIN_MOTION_LEN_SQ:
					ai_body.move_and_collide(slide_after)
			return

	var slide_rem: Vector2 = remainder.slide(col.get_normal())
	if slide_rem.length_squared() >= MIN_MOTION_LEN_SQ:
		ai_body.move_and_collide(slide_rem)

## Sprawdza fizycznie, czy cel (gracz) ma za plecami ścianę, lawę lub twardą przeszkodę w zasięgu wall_check_dist_px.
static func is_target_backed_against_wall(
	entity: CharacterEntity,
	target: Variant,
	wall_check_dist_px: float = DEFAULT_WALL_BEHIND_CHECK_DISTANCE_PX
) -> bool:
	if not is_instance_valid(entity) or not is_instance_valid(target) or not (target is CharacterEntity):
		return false

	var target_char: CharacterEntity = target as CharacterEntity
	if target_char.is_on_wall():
		return true

	var world_2d: World2D = target_char.get_world_2d()
	if world_2d == null:
		return false

	var dir_ai_to_target: Vector2 = entity.global_position.direction_to(target_char.global_position)
	if dir_ai_to_target == Vector2.ZERO:
		dir_ai_to_target = Vector2.DOWN

	var check_dist: float = target_char.get_effective_combat_radius() + maxf(10.0, wall_check_dist_px)
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	var excluded: Array[RID] = [target_char.get_rid(), entity.get_rid()]

	# Skanujemy półkole za plecami gracza (0, +/-35 deg, +/-70 deg), aby wykryć również ukośne schodki lawy i narożniki!
	var check_angles: Array[float] = [0.0, 0.6, -0.6, 1.2, -1.2]
	for angle_offset in check_angles:
		var ray_dir: Vector2 = dir_ai_to_target.rotated(angle_offset)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			target_char.global_position,
			target_char.global_position + (ray_dir * check_dist)
		)
		query.collision_mask = WALL_AND_OBSTACLES_MASK
		query.exclude = excluded
		if not space_state.intersect_ray(query).is_empty():
			return true

	return false

## Wylicza dla AI/Bossa wektor odblokowania przejścia, gdy gracz jest przyciśnięty do ściany i próbuje wyjść z narożnika.
## Korzysta bezpośrednio z wall_escape_corridor_distance oraz wall_pin_detection_distance z AIBehaviorProfile!
static func calculate_wall_escape_vector(
	entity: CharacterEntity,
	target: Variant,
	corridor_distance_px: float = DEFAULT_WALL_ESCAPE_CORRIDOR_PX,
	wall_check_dist_px: float = DEFAULT_WALL_BEHIND_CHECK_DISTANCE_PX
) -> Vector2:
	if not is_instance_valid(entity) or not is_instance_valid(target) or not (target is CharacterEntity):
		return Vector2.ZERO

	var target_char: CharacterEntity = target as CharacterEntity
	if target_char.is_dead:
		return Vector2.ZERO

	var edge_dist: float = CharacterEntity.get_edge_distance_between(entity, target_char)
	if edge_dist > corridor_distance_px:
		return Vector2.ZERO

	if not is_target_backed_against_wall(entity, target_char, wall_check_dist_px):
		return Vector2.ZERO

	var player_input: Vector2 = (
		Vector2(target_char.get_meta("crowd_desired_input_dir"))
		if target_char.has_meta("crowd_desired_input_dir")
		else target_char.velocity
	)
	# Dopóki gracz nie naciska klawiszy ruchu, boss może stać tuż przy nim na styk.
	# Gdy tylko gracz próbuje wyjść spod ściany, boss natychmiast robi mu korytarz o szerokości corridor_distance_px!
	if player_input.length_squared() <= 0.001:
		return Vector2.ZERO

	var player_move_dir: Vector2 = player_input.normalized()
	var dir_target_to_ai: Vector2 = target_char.global_position.direction_to(entity.global_position)
	if dir_target_to_ai == Vector2.ZERO:
		dir_target_to_ai = Vector2.RIGHT

	var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
	var lateral_offset: float = (entity.global_position - target_char.global_position).dot(right_normal)
	var side_sign: float = _resolve_consistent_parting_side(entity, lateral_offset)

	var urgency: float = clampf(1.0 - (edge_dist / maxf(1.0, corridor_distance_px)), 0.35, 1.0)
	var radial_relief: Vector2 = dir_target_to_ai * PARTING_RADIAL_WEIGHT
	var tangent_relief: Vector2 = (right_normal * side_sign) * WALL_ESCAPE_TANGENT_WEIGHT
	return (radial_relief + tangent_relief).normalized() * urgency

static func _resolve_consistent_parting_side(ai_body: Node, lateral_offset: float) -> float:
	if absf(lateral_offset) >= 6.0:
		return 1.0 if lateral_offset > 0.0 else -1.0
	return 1.0 if (ai_body.get_instance_id() % 2 == 0) else -1.0
