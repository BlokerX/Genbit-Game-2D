class_name CrowdCollisionController
extends RefCounted
## Dedykowany kontroler fizyki tłumu i ochrony przed przygwożdżeniem gracza do ściany (SOLID - SRP).
## Działa w 100% na twardych kolizjach fizycznych (nigdy nie wyłącza collision_mask gracza ani wrogów!).

# --- STAŁE FIZYKI TŁUMU I ANTY-DOCISKU DO ŚCIANY (Brak magicznych liczb) ---
## Maska warstw fizyki dla ścian/lawy (bit 1) oraz postawionych obiektów (bit 32).
const WALL_AND_OBSTACLES_MASK: int = 33
## Odległość sondowania ściany za plecami gracza (w pikselach od krawędzi kolidera gracza).
const WALL_BEHIND_CHECK_DISTANCE_PX: float = 54.0
## Maksymalny dystans krawędziowy bezpośredniego kontaktu gracza z 1. rzędem wrogów (w pikselach).
const CONTACT_TRIGGER_MARGIN_PX: float = 16.0
## Zasięg łańcuchowego przekazywania rozpychania na 2. i 3. rząd lekkich jednostek w roju (w pikselach).
const CHAIN_PARTING_RELAY_RANGE_PX: float = 95.0
## Dodatkowa szerokość korytarza ruchu gracza (w pikselach po obu stronach kapsuły gracza).
const PARTING_CORRIDOR_EXTRA_WIDTH_PX: float = 36.0
## Prędkość bocznego rozsuwania lekkich jednostek roju podczas napierania gracza (w pikselach na sekundę).
const CHAIN_PARTING_SPEED_PX: float = 240.0
## Waga składowej stycznej (bocznej) podczas rozsuwania roju.
const PARTING_TANGENTIAL_WEIGHT: float = 1.65
## Waga składowej promieniowej (odpychającej od środka gracza).
const PARTING_RADIAL_WEIGHT: float = 0.45
## Minimalny mnożnik podatności na pchnięcie, poniżej którego jednostka jest nieprzesuwalna dla gracza (np. Boss).
const MIN_PUSHABLE_MULTIPLIER: float = 0.02
## Minimalny kwadrat długości wektora reszty przy ześlizgu po ścianie.
const MIN_SLIDE_REMAINDER_SQ: float = 0.01
## Kwadrat minimalnej prędkości celu uznawanej za aktywny ruch gracza.
const ACTIVE_TARGET_SPEED_SQ_THRESHOLD: float = 25.0
## Minimalny iloczyn skalarny oznaczający, że gracz idzie w stronę danej jednostki AI.
const PLAYER_APPROACH_DOT_THRESHOLD: float = 0.15
## Mnożnik siły schodzenia AI na bok, gdy gracz próbuje wyjść z narożnika lub roju.
const AI_ESCAPE_SIDE_STEP_WEIGHT: float = 1.75
## Promień wokół gracza, w którym jednostki roju same schodzą na boki przed idącym graczem.
const AI_SELF_PARTING_RADIUS_PX: float = 135.0

## Rozsuwa łańcuchowo (od zewnętrznego rzędu do wewnętrznego) lekkie jednostki roju, na które napiera gracz.
## Ciężkie jednostki i bossowie (get_crowd_push_multiplier() == 0.0) pozostają niewzruszeni.
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
	var has_direct_contact_in_front: bool = false

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
		if edge_dist > CHAIN_PARTING_RELAY_RANGE_PX:
			continue

		var center_dist: float = player_pos.distance_to(ai_entity.global_position)
		var to_ai: Vector2 = (ai_entity.global_position - player_pos) / maxf(0.001, center_dist)
		var forward_dot: float = to_ai.dot(move_dir)

		if edge_dist <= CONTACT_TRIGGER_MARGIN_PX and forward_dot >= -0.1:
			has_direct_contact_in_front = true

		if forward_dot >= -0.1:
			candidates.append({
				"entity": ai_entity,
				"center_dist": center_dist,
				"edge_dist": edge_dist,
				"push_mult": push_mult
			})

	if not has_direct_contact_in_front or candidates.is_empty():
		return

	# Sortujemy od NAJDALSZEGO rzędu do NAJBLIŻSZEGO (3. rząd odsuwa się najpierw, robiąc miejsce 2. i 1. rzędowi!)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["center_dist"]) > float(b["center_dist"])
	)

	for entry in candidates:
		var ai_body: AICharacterEntity = entry["entity"] as AICharacterEntity
		if not is_instance_valid(ai_body):
			continue
		_displace_pushable_ai_laterally(
			ai_body,
			player_pos,
			move_dir,
			float(entry["edge_dist"]),
			float(entry["push_mult"]),
			corridor_half_width,
			delta
		)

## Przemieszcza pojedynczą lekką jednostkę AI na zewnątrz korytarza ruchu gracza za pomocą move_and_collide.
func _displace_pushable_ai_laterally(
	ai_body: AICharacterEntity,
	player_pos: Vector2,
	player_move_dir: Vector2,
	edge_dist: float,
	push_mult: float,
	corridor_half_width: float,
	delta: float
) -> void:
	var rel_pos: Vector2 = ai_body.global_position - player_pos
	var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
	var lateral_offset: float = rel_pos.dot(right_normal)

	if absf(lateral_offset) > corridor_half_width + ai_body.get_effective_combat_radius():
		return

	var side_sign: float = _resolve_consistent_parting_side(ai_body, lateral_offset)
	var lateral_dir: Vector2 = right_normal * side_sign
	var radial_dir: Vector2 = rel_pos.normalized() if rel_pos.length_squared() > 0.01 else player_move_dir
	var push_dir: Vector2 = (
		(lateral_dir * PARTING_TANGENTIAL_WEIGHT) + (radial_dir * PARTING_RADIAL_WEIGHT)
	).normalized()

	var closeness: float = clampf(1.0 - (edge_dist / CHAIN_PARTING_RELAY_RANGE_PX), 0.25, 1.0)
	var step_motion: Vector2 = push_dir * (CHAIN_PARTING_SPEED_PX * closeness * push_mult * delta)

	var col: KinematicCollision2D = ai_body.move_and_collide(step_motion)
	if col != null:
		var slide_rem: Vector2 = col.get_remainder().slide(col.get_normal())
		if slide_rem.length_squared() > MIN_SLIDE_REMAINDER_SQ:
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

	# Sprawdzamy promień bezpośrednio za plecami gracza oraz pod kątem +/- 40 stopni (narożniki i ukośna lawa!)
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
## Działa również na Giga Bossach (Posmita / Paxie) poprzez ich własny ruch AI, dzięki czemu boss sam zostawia przejście!
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

	# Jeśli gracz aktywnie próbuje wyjść z narożnika/zwarcia, AI dodatkowo schodzi po stycznej w bok
	if target_char.velocity.length_squared() >= ACTIVE_TARGET_SPEED_SQ_THRESHOLD:
		var player_move_dir: Vector2 = target_char.velocity.normalized()
		var approach_dot: float = player_move_dir.dot(dir_target_to_ai)
		if approach_dot > PLAYER_APPROACH_DOT_THRESHOLD:
			var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
			var lateral_offset: float = (entity.global_position - target_char.global_position).dot(right_normal)
			var side_sign: float = _resolve_consistent_parting_side(entity, lateral_offset)
			yield_vec += (right_normal * side_sign) * (approach_dot * AI_ESCAPE_SIDE_STEP_WEIGHT)

	return yield_vec

## Wylicza dla lekkich jednostek roju wektor schodzenia z linii marszu gracza (otwiera korytarz w wielowarstwowym roju).
static func calculate_swarm_parting_vector_for_ai(
	entity: CharacterEntity,
	target: Variant
) -> Vector2:
	if not is_instance_valid(entity) or not is_instance_valid(target) or not (target is CharacterEntity):
		return Vector2.ZERO

	# Ciężkie bossy nie uciekają z linii marszu gracza na otwartym polu (robią miejsce tylko pod ścianą powyżej)
	var push_mult: float = entity.get_crowd_push_multiplier()
	if push_mult < MIN_PUSHABLE_MULTIPLIER:
		return Vector2.ZERO

	var target_char: CharacterEntity = target as CharacterEntity
	if target_char.is_dead or target_char.velocity.length_squared() < ACTIVE_TARGET_SPEED_SQ_THRESHOLD:
		return Vector2.ZERO

	var edge_dist: float = CharacterEntity.get_edge_distance_between(entity, target_char)
	if edge_dist > AI_SELF_PARTING_RADIUS_PX:
		return Vector2.ZERO

	var player_move_dir: Vector2 = target_char.velocity.normalized()
	var rel_pos: Vector2 = entity.global_position - target_char.global_position
	var dir_to_ai: Vector2 = rel_pos.normalized()
	var forward_dot: float = player_move_dir.dot(dir_to_ai)

	if forward_dot <= PLAYER_APPROACH_DOT_THRESHOLD:
		return Vector2.ZERO

	var right_normal := Vector2(-player_move_dir.y, player_move_dir.x)
	var lateral_offset: float = rel_pos.dot(right_normal)
	var corridor_width: float = target_char.get_effective_combat_radius() + entity.get_effective_combat_radius() + PARTING_CORRIDOR_EXTRA_WIDTH_PX

	if absf(lateral_offset) > corridor_width:
		return Vector2.ZERO

	var side_sign: float = _resolve_consistent_parting_side(entity, lateral_offset)
	var closeness: float = clampf(1.0 - (edge_dist / AI_SELF_PARTING_RADIUS_PX), 0.25, 1.0)
	return ((right_normal * side_sign * PARTING_TANGENTIAL_WEIGHT) + (dir_to_ai * PARTING_RADIAL_WEIGHT)).normalized() * closeness * push_mult

## Wyznacza spójny kierunek zejścia na bok (w lewo lub w prawo) względem wektora ruchu gracza.
static func _resolve_consistent_parting_side(ai_body: Node, lateral_offset: float) -> float:
	if absf(lateral_offset) >= 4.0:
		return 1.0 if lateral_offset > 0.0 else -1.0
	return 1.0 if (ai_body.get_instance_id() % 2 == 0) else -1.0
