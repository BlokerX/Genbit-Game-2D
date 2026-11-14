extends Resource
class_name AIAbility

const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
## Domyślny promień kolizji bojowej dla atakującego, jeśli nie zdefiniowano combat_radius.
const DEFAULT_ENTITY_COMBAT_RADIUS: float = 40.0
## Domyślny promień kolizji bojowej dla celu, jeśli nie zdefiniowano combat_radius.
const DEFAULT_TARGET_COMBAT_RADIUS: float = 20.0
## Minimalny kwadrat przesunięcia po ześlizgu na ścianie, poniżej którego ruch jest ignorowany.
const MIN_SLIDE_REMAINDER_SQ: float = 0.01
## Minimalny czas trwania Tweena zabezpieczający przed dzieleniem przez zero.
const MIN_TWEEN_DURATION_SEC: float = 0.01

@export var ability_name: String = "Special Ability"
@export var cooldown: float = 5.0
@export var min_range: float = 0.0
@export var max_range: float = 200.0
## Oprawa odtwarzana przy wykonaniu zdolności specjalnej przeciwnika.
@export var feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemies/enemy_super_attack.tres"
)

@export_category("Inteligencja i Wyjątki")
## O ile sekund AI musi być w aktywnej walce, zanim rzuci ten czar po raz pierwszy?
## Zapobiega to używaniu potężnych ataków w ułamku sekundy po zauważeniu gracza.
@export var first_cast_delay: float = 5.0

## Szansa na rzucenie czaru, gdy jest gotowy (np. 0.6 = 60%).
## Jeśli AI oblało rzut, odczeka ułamek sekundy przed kolejną próbą (wahanie).
@export_range(0.0, 1.0) var cast_chance: float = 0.7 

## Jeśli włączone, AI może rzucić umiejętność NAWET jeśli inna jest aktualnie wykonywana.
@export var ignore_global_cast_lock: bool = false

## Zwraca true, jeśli zdolność jest gotowa do użycia (sprawdza dystans i warunki specjalne).
func check_conditions(_attacker: CharacterEntity, _target: CharacterEntity, distance: float) -> bool:
	if distance < min_range or distance > max_range:
		return false
	return true

## Główna logika umiejętności, nadpisywana w konkretnych plikach.
func execute(_attacker: CharacterEntity, _target: CharacterEntity) -> void:
	pass

# =========================================================================
# WSPÓLNE METODY POMOCNICZE DLA ZDOLNOŚCI AI (Zasady DRY i SOLID)
# =========================================================================

## Pobiera AICombatController i ustawia flagę rzucania umiejętności (is_casting_ability).
static func set_casting_state(attacker: CharacterEntity, is_casting: bool) -> AICombatController:
	if not is_instance_valid(attacker):
		return null
	var ai_controller: Node = attacker.get_node_or_null("AIController")
	var combat_ctrl: AICombatController = (
		ai_controller.get_node_or_null("AICombatController") as AICombatController
		if ai_controller != null
		else null
	)
	if combat_ctrl != null:
		combat_ctrl.is_casting_ability = is_casting
	return combat_ctrl

## Sprawdza w profilu zachowania AI, czy postać obraca się płynnie (rotacyjnie), czy klatkowo (8 kierunków).
static func can_entity_rotate(attacker: CharacterEntity) -> bool:
	if not is_instance_valid(attacker):
		return false
	var ai_controller: Node = attacker.get_node_or_null("AIController")
	if ai_controller != null and ai_controller.get("behavior_profile") != null:
		return bool(ai_controller.behavior_profile.can_rotate_to_target)
	return false

## Obraca postać w podanym kierunku zgodnie z jej profilem zachowania (płynny obrót lub 8-kierunkowy sprite).
static func orient_towards(attacker: CharacterEntity, direction: Vector2, lerp_weight: float = 1.0) -> void:
	if not is_instance_valid(attacker) or direction == Vector2.ZERO:
		return
	if can_entity_rotate(attacker):
		var target_angle: float = direction.angle()
		if lerp_weight >= 1.0:
			attacker.rotation = target_angle
		else:
			attacker.rotation = lerp_angle(attacker.rotation, target_angle, lerp_weight)
	elif attacker.has_method("_update_sprite_direction"):
		attacker._update_sprite_direction(direction)

## Bezpiecznie spawnuje węzeł pomocniczy umiejętności (plamę, laser, falę) w strukturze Mapy.
static func spawn_ability_node(attacker: Node2D, node_to_spawn: Node2D, spawn_pos: Vector2) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(node_to_spawn):
		return
	node_to_spawn.global_position = spawn_pos
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", node_to_spawn, spawn_pos)
		return
	var parent_node: Node = attacker.get_parent()
	if parent_node != null:
		parent_node.add_child(node_to_spawn)
		node_to_spawn.global_position = spawn_pos
	elif attacker.is_inside_tree() and attacker.get_tree().current_scene != null:
		attacker.get_tree().current_scene.add_child(node_to_spawn)
		node_to_spawn.global_position = spawn_pos

## Oblicza dystans od krawędzi do krawędzi (Edge-to-Edge) pomiędzy dwoma obiektami (DRY - z uwzględnieniem skali bossów).
static func get_edge_distance(entity_a: Variant, entity_b: Variant) -> float:
	return CharacterEntity.get_edge_distance_between(entity_a, entity_b)

## Deleguje sprawdzenie sojuszu do FactionComponent (parametry Variant chronią przed błędem 'previously freed').
static func is_ally_of(attacker: Variant, target: Variant, fallback_faction_name: StringName = &"") -> bool:
	return FactionComponent.is_ally_of(attacker, target, fallback_faction_name)

## Wywołuje wstrząs kamery gracza (naprawia błąd szukania CameraComponent bezpośrednio w current_scene).
static func trigger_camera_shake(context_node: Node, trauma_amount: float) -> void:
	if trauma_amount <= 0.0 or not is_instance_valid(context_node) or not context_node.is_inside_tree():
		return
	var tree: SceneTree = context_node.get_tree()
	if tree == null:
		return

	# 1. Sprawdzamy aktywną kamerę 2D w Viewporcie
	var viewport: Viewport = context_node.get_viewport()
	if viewport != null:
		var active_cam: Camera2D = viewport.get_camera_2d()
		if is_instance_valid(active_cam) and active_cam.has_method("add_trauma"):
			active_cam.call("add_trauma", trauma_amount)
			return

	# 2. Fallback: Szukamy CameraComponent u gracza
	var player: Node = tree.get_first_node_in_group("Player")
	if is_instance_valid(player):
		var player_cam: Node = player.get_node_or_null("CameraComponent")
		if is_instance_valid(player_cam) and player_cam.has_method("add_trauma"):
			player_cam.call("add_trauma", trauma_amount)

## Tworzy bezpiecznego fizycznie Tweena szarży/skoku (move_and_collide zamiast nadpisywania global_position).
## Gwarantuje, że skaczący boss NIGDY nie wepchnie gracza w ścianę ani sam nie wypadnie poza mapę!
static func create_kinematic_dash_tween(
	attacker: CharacterEntity,
	target_world_pos: Vector2,
	duration: float,
	trans_type: Tween.TransitionType = Tween.TRANS_QUAD,
	ease_type: Tween.EaseType = Tween.EASE_OUT
) -> Tween:
	var tween: Tween = attacker.create_tracked_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(trans_type).set_ease(ease_type)

	var last_virtual_pos: Array[Vector2] = [attacker.global_position]
	var start_pos: Vector2 = attacker.global_position

	tween.tween_method(
		func(interpolated_pos: Vector2):
			if not is_instance_valid(attacker) or not attacker.is_inside_tree():
				return
			var step_motion: Vector2 = interpolated_pos - last_virtual_pos[0]
			last_virtual_pos[0] = interpolated_pos
			if step_motion.length_squared() <= 0.0001:
				return
			var collision: KinematicCollision2D = attacker.move_and_collide(step_motion)
			if collision != null:
				var slide_vec: Vector2 = collision.get_remainder().slide(collision.get_normal())
				if slide_vec.length_squared() > MIN_SLIDE_REMAINDER_SQ:
					attacker.move_and_collide(slide_vec),
		start_pos,
		target_world_pos,
		maxf(MIN_TWEEN_DURATION_SEC, duration)
	)
	return tween
