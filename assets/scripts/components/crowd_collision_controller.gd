class_name CrowdCollisionController
extends RefCounted
## Dedykowany kontroler fizyki tłumu i ochrony przed przygwożdżeniem gracza do ściany (SOLID - SRP).
## Działa w 100% na twardych kolizjach fizycznych (nigdy nie wyłącza collision_mask gracza ani wrogów!).
## Obsługuje kaskadowe (łańcuchowe) rozpychanie wielowarstwowego roju oraz detekcję docisku pod ścianą.

# --- STAŁE FIZYKI TŁUMU I ANTY-DOCISKU DO ŚCIANY (Brak magicznych liczb) ---
## Maska warstw fizyki dla ścian/lawy (bit 1) oraz postawionych obiektów (bit 32).
const WALL_AND_OBSTACLES_MASK: int = 33
## Odległość sondowania ściany za plecami gracza (w pikselach od krawędzi kolidera gracza).
const WALL_BEHIND_CHECK_DISTANCE_PX: float = 54.0
## Maksymalny dystans krawędziowy od gracza inicjujący rozsuwanie pierwszego rzędu (w pikselach).
const CONTACT_TRIGGER_MARGIN_PX: float = 28.0
## Zasięg fali rozsuwającej wielowarstwowy rój przed idącym graczem (obejmuje do 4-5 pierścieni pająków).
const SWARM_WAVE_INFLUENCE_RANGE_PX: float = 280.0
## Dodatkowa szerokość korytarza torowanego przez gracza w tłumie (w pikselach na każdą stronę).
const PARTING_CORRIDOR_EXTRA_WIDTH_PX: float = 75.0
## Prędkość boczno-promieniowego rozsuwania jednostek roju przed idącym graczem (w pikselach na sekundę).
const SWARM_WAVE_PARTING_SPEED_PX: float = 340.0
## Waga składowej stycznej (rozsuwanie na lewo i prawo od osi ruchu gracza).
const PARTING_TANGENTIAL_WEIGHT: float = 1.75
## Waga składowej promieniowej (odpychanie od środka gracza).
const PARTING_RADIAL_WEIGHT: float = 0.85
## Maksymalna głębokość rekurencji przy łańcuchowym przepychaniu kolejnych rzędów wrogów (Domino Push).
const MAX_CHAIN_PUSH_DEPTH: int = 5
## Współczynnik tłumienia siły przekazywanej na każdy kolejny rząd w łańcuchu kolizji.
const CHAIN_PUSH_ATTENUATION: float = 0.88
## Czas (w milisekundach), przez który odsunięty wróg utrzymuje kierunek zejścia z drogi w swojej nawigacji.
const PARTING_NAVIGATION_OVERRIDE_MSEC: int = 140
## Minimalny mnożnik podatności na pchnięcie, poniżej którego jednostka jest nieprzesuwalna (np. Boss 3x).
const MIN_PUSHABLE_MULTIPLIER: float = 0.02
## Minimalny kwadrat długości wektora ruchu uznawany za istotne przesunięcie.
const MIN_MOTION_LEN_SQ: float = 0.005
## Kwadrat minimalnej prędkości celu uznawanej za aktywny ruch gracza.
const ACTIVE_TARGET_SPEED_SQ_THRESHOLD: float = 25.0
## Minimalny iloczyn skalarny oznaczający, że gracz idzie w stronę danej jednostki AI.
const PLAYER_APPROACH_DOT_THRESHOLD: float = 0.10
## Mnożnik siły schodzenia AI na bok, gdy gracz próbuje wyjść z narożnika lub roju.
const AI_ESCAPE_SIDE_STEP_WEIGHT: float = 1.85

## Rozsuwa wielowarstwowy rój lekkich jednostek przed idącym graczem (od zewnętrznego pierścienia do wewnętrznego)
## za pomocą łańcuchowego przekazywania kolizji. Ciężkie bossy (push_mult == 0.0) pozostają niewzruszone.
func process_player_crowd_interaction(
	player: CharacterEntity,
	desired_input_dir: Vector2,
	delta: float
) -> void:
	if not is_instance_valid(player) or player.is_dead or player.is_respawning:
		return
	if desired_input_dir.length_squared() <= 0.001:
		return

	var tree: SceneTree = player.get_tree()
	if tree == null:
		return

	var move_dir: Vector2 = desired_input_dir.normalized()
	var player_pos: Vector2 = player.global_position
	var player_rad: float = player.get_effective_combat_radius()
	var corridor_half_width: float = player_rad + PARTING_CORRIDOR_EXTRA_WIDTH_PX

	var candidates: Array[Dictionary] = []
	var has_close_blocker: bool = false

	for node in PerceptionComponent.get_shared_characters(tree):
		if not is_instance_valid(node) or node == player or node.is_queued_for_deletion():
			continue
		if not (node is AICharacterEntity):
			continue
		var ai_entity: AICharacterEntity = node as AICharacterEntity
		if ai_entity.is_dead:
			continue

		var push_mult: float = ai_entity.get_crowd_push_multiplier()
		if push_mult < MIN_PUSHABLE_MULTIPLIER:
			continue

		var edge_dist: float = CharacterEntity.get_edge_distance_between(player, ai_entity)
		if edge_dist > SWARM_WAVE_INFLUENCE_RANGE_PX:
			continue

		var center_dist: float = player_pos.distance_to(ai_entity.global_position)
		var to_ai: Vector2 = (ai_entity.global_position - player_pos) / maxf(0.001, center_dist)
		var forward_dot: float = to_ai.dot(move_dir)

		if edge_dist <= CONTACT_TRIGGER_MARGIN_PX and forward_dot >= -0.25:
			has_close_blocker = true

		if forward_dot >= -0.25:
			candidates.append({
				"entity": ai_entity,
				"center_dist": center_dist,
				"edge_dist": edge_dist,
				"push_mult": push_mult
			})

	if not has_close_blocker or candidates.is_empty():
		return

	# Sortujemy od NAJDALSZEGO pierścienia do NAJBLIŻSZEGO, aby zewnętrzne rzędy zrobiły miejsce wewnętrznym!
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["center_dist"]) > float(b["center_dist"])
	)

	var now_msec: int = Time.get_ticks_msec()
	for entry in candidates:
		var ai_body: AICharacterEntity = entry["entity"] as AICharacterEntity
		if not is_instance_valid(ai_body):
			continue
		_part_single_ai_in_swarm(
			ai_body,
			player_pos,
			move_dir,
			float(entry["edge_dist"]),
			float(entry["push_mult"]),
			corridor_half_width,
			now_msec,
			delta
		)

## Wywoływane przy bezpośrednim zderzeniu gracza z wrogiem w move_and_slide(): przepycha kaskadowo cały rząd za wrogiem.
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

	var push_mult: float = first_blocker.get_crowd_push_multiplier()
	if push_mult < MIN_PUSHABLE_MULTIPLIER:
		return

	var move_dir: Vector2 = (
		desired_input_dir.normalized()
		if desired_input_dir.length_squared() > 0.001
		else -collision_normal
	)
	var rel_pos: Vector2 = first_blocker.global_position - player.global_position
	var right_normal := Vector2(-move_dir.y, move_dir.x)
	var lateral_offset: float = rel_pos.dot(right_normal)
	var side_sign: float = _resolve_consistent_parting_side(first_blocker, lateral_offset)

	var push_dir: Vector2 = (
		(-collision_normal * PARTING_RADIAL_WEIGHT)
		+ ((right_normal * side_sign) * PARTING_TANGENTIAL_WEIGHT)
	).normalized()

	var step_motion: Vector2 = push_dir * (push_speed_px * push_mult * delta)
	first_blocker.set_meta("crowd_parted_until_msec", Time.get_ticks_msec() + PARTING_NAVIGATION_OVERRIDE_MSEC)
	first_blocker.set_meta("crowd_parting_dir", push_dir)

	var visited: Array[int] = [player.get_instance_id()]
	_move_ai_with_chain_push(first_blocker, step_motion, 0, visited)

## Wylicza wektor rozstąpienia dla pojedynczego wroga w korytarzu przed graczem i przesuwa go kaskadowo.
func _part_single_ai_in_swarm(
	ai_body: AICharacterEntity,
	player_pos: Vector2,
	player_move_dir: Vector2,
	edge_dist: float,
	push_mult: float,
	corridor_half_width: float,
	now_msec: int,
	delta: float
) -> void:
	var rel_pos: Vector2 = ai_body.global_position - player_pos
	var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
	var lateral_offset: float = rel_pos.dot(right_normal)
	var max_width: float = corridor_half_width + ai_body.get_effective_combat_radius()

	if absf(lateral_offset) > max_width:
		return

	var side_sign: float = _resolve_consistent_parting_side(ai_body, lateral_offset)
	var lateral_dir: Vector2 = right_normal * side_sign
	var radial_dir: Vector2 = rel_pos.normalized() if rel_pos.length_squared() > 0.01 else player_move_dir
	var push_dir: Vector2 = (
		(lateral_dir * PARTING_TANGENTIAL_WEIGHT) + (radial_dir * PARTING_RADIAL_WEIGHT)
	).normalized()

	# Zapisujemy kierunek torowania dla AINavigationController, aby pająk w tej samej klatce nie parł z powrotem na gracza!
	ai_body.set_meta("crowd_parted_until_msec", now_msec + PARTING_NAVIGATION_OVERRIDE_MSEC)
	ai_body.set_meta("crowd_parting_dir", push_dir)

	var distance_factor: float = clampf(1.0 - (edge_dist / SWARM_WAVE_INFLUENCE_RANGE_PX), 0.25, 1.0)
	var lateral_factor: float = clampf(1.0 - (absf(lateral_offset) / maxf(1.0, max_width)), 0.35, 1.0)
	var step_motion: Vector2 = push_dir * (SWARM_WAVE_PARTING_SPEED_PX * distance_factor * lateral_factor * push_mult * delta)

	var visited: Array[int] = []
	_move_ai_with_chain_push(ai_body, step_motion, 0, visited)

## Rekurencyjnie przemieszcza jednostkę AI: jeśli na jej drodze stoi inny przesuwalny wróg (np. 2., 3., 4. rząd pająków),
## najpierw przepycha wroga z dalszego rzędu, a następnie domyka ruch bieżącej jednostki (efekt domina w tłumie).
func _move_ai_with_chain_push(
	ai_body: AICharacterEntity,
	motion: Vector2,
	depth: int,
	visited_ids: Array[int]
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
	# Jeśli uderzono w innego przesuwalnego pająka/wroga z kolejnego rzędu -> przepychamy go łańcuchowo!
	if is_instance_valid(collider) and collider is AICharacterEntity:
		var blocker_ai: AICharacterEntity = collider as AICharacterEntity
		var blocker_mult: float = blocker_ai.get_crowd_push_multiplier()
		if not blocker_ai.is_dead and blocker_mult >= MIN_PUSHABLE_MULTIPLIER:
			var push_normal: Vector2 = -col.get_normal()
			var chain_dir: Vector2 = (push_normal + motion.normalized()).normalized()
			var transferred_motion: Vector2 = chain_dir * (remainder.length() * CHAIN_PUSH_ATTENUATION * blocker_mult)

			blocker_ai.set_meta("crowd_parted_until_msec", Time.get_ticks_msec() + PARTING_NAVIGATION_OVERRIDE_MSEC)
			blocker_ai.set_meta("crowd_parting_dir", chain_dir)

			_move_ai_with_chain_push(blocker_ai, transferred_motion, depth + 1, visited_ids)

			# Po odsunięciu pająka z dalszego rzędu ponawiamy dokończenie ruchu pierwszego pająka!
			var second_col: KinematicCollision2D = ai_body.move_and_collide(remainder)
			if second_col != null:
				var slide_after: Vector2 = second_col.get_remainder().slide(second_col.get_normal())
				if slide_after.length_squared() >= MIN_MOTION_LEN_SQ:
					ai_body.move_and_collide(slide_after)
			return

	# Jeśli uderzono w twardą ścianę lub nieprzesuwalnego Bossa -> płynny ześlizg po normalnej
	var slide_rem: Vector2 = remainder.slide(col.get_normal())
	if slide_rem.length_squared() >= MIN_MOTION_LEN_SQ:
		ai_body.move_and_collide(slide_rem)

## Sprawdza fizycznie (is_on_wall oraz RayCast za plecami celu), czy cel (gracz) ma za sobą ścianę, lawę lub przeszkodę.
static func is_target_backed_against_wall(entity: CharacterEntity, target: Variant) -> bool:
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

	var check_dist: float = target_char.get_effective_combat_radius() + WALL_BEHIND_CHECK_DISTANCE_PX
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	var excluded: Array[RID] = [target_char.get_rid(), entity.get_rid()]

	var check_angles: Array[float] = [0.0, 0.7, -0.7]
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

## Wylicza dla AI wektor odsunięcia się (ustąpienia pola), aby NIGDY nie dociskać gracza do ściany.
static func calculate_wall_escape_vector(
	entity: CharacterEntity,
	target: Variant,
	personal_space_margin: float,
	wall_escape_corridor_px: float
) -> Vector2:
	if not is_instance_valid(entity) or not is_instance_valid(target) or not (target is CharacterEntity):
		return Vector2.ZERO

	var target_char: CharacterEntity = target as CharacterEntity
	if target_char.is_dead:
		return Vector2.ZERO

	var edge_dist: float = CharacterEntity.get_edge_distance_between(entity, target_char)
	var is_pinned_to_wall: bool = is_target_backed_against_wall(entity, target_char)
	var required_gap: float = wall_escape_corridor_px if is_pinned_to_wall else personal_space_margin

	if edge_dist >= required_gap:
		return Vector2.ZERO

	var dir_target_to_ai: Vector2 = target_char.global_position.direction_to(entity.global_position)
	if dir_target_to_ai == Vector2.ZERO:
		dir_target_to_ai = Vector2.RIGHT

	var urgency: float = clampf(1.0 - (edge_dist / maxf(1.0, required_gap)), 0.25, 1.0)
	var yield_vec: Vector2 = dir_target_to_ai * urgency

	if target_char.velocity.length_squared() >= ACTIVE_TARGET_SPEED_SQ_THRESHOLD:
		var player_move_dir: Vector2 = target_char.velocity.normalized()
		var approach_dot: float = player_move_dir.dot(dir_target_to_ai)
		if approach_dot > PLAYER_APPROACH_DOT_THRESHOLD:
			var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
			var lateral_offset: float = (entity.global_position - target_char.global_position).dot(right_normal)
			var side_sign: float = _resolve_consistent_parting_side(entity, lateral_offset)
			yield_vec += (right_normal * side_sign) * (approach_dot * AI_ESCAPE_SIDE_STEP_WEIGHT)

	return yield_vec

## Wyznacza spójny kierunek zejścia na bok (w lewo lub w prawo) względem wektora ruchu gracza.
static func _resolve_consistent_parting_side(ai_body: Node, lateral_offset: float) -> float:
	if absf(lateral_offset) >= 6.0:
		return 1.0 if lateral_offset > 0.0 else -1.0
	return 1.0 if (ai_body.get_instance_id() % 2 == 0) else -1.0
