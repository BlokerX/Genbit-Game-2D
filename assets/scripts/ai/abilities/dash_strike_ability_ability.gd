extends AIAbility
class_name DashStrikeAbility
## Uniwersalny archetyp szybkiego doskoku z uderzeniem w szczycie ruchu i opcjonalnym powrotem (SOLID - SRP / OCP / DRY).
## Obrażenia, kryt, penetrację, stun i odrzut definiuje AttackData, a zachowania specjalne (np. wytrącenie przedmiotu
## przez StealItemAbilityComponent czy wstrząs kamery przez CameraShakeAbilityComponent) podpina się w .tres!

#region Stałe Domenowe (Brak magicznych liczb)
const HALF_CAST_TIME_FACTOR: float = 0.5
const DEBUG_VISUAL_Z_INDEX: int = 100
const DEFAULT_DASH_MAX_RANGE: float = 110.0
const IMPACT_SPARK_COUNT: int = 7
const IMPACT_SPARK_RADIUS_PX: float = 24.0
#endregion

@export_category("Archetyp: Doskok z Uderzeniem (DashStrikeAbility)")

@export_group("Parametry Doskoku i Trafienia")
## Całkowity czas trwania animacji doskoku (w obie strony, jeśli włączono powrót).
@export_range(0.1, 2.0, 0.05) var cast_time: float = 0.3
## Maksymalny dystans (w pikselach), na jaki rzucający doskakuje w kierunku celu.
@export_range(10.0, 400.0, 10.0) var dash_distance: float = 120.0
## Margines tolerancji dystansu (od krawędzi do krawędzi) w szczycie doskoku.
@export_range(0.0, 150.0, 5.0) var hit_distance_leeway: float = 60.0
## Czy po wykonaniu uderzenia rzucający ma natychmiast odskoczyć na pozycję startową?
@export var return_to_start_position: bool = true

@export_group("Wizualizacje i Debug")
## Kolor rozbłysku iskier w chwili trafienia celu.
@export var impact_vfx_color: Color = Color(1.0, 0.85, 0.35, 0.95)
## Jeśli włączone, rysuje pomocniczy okrąg zasięgu trafienia i wypisuje logi diagnostyczne w konsoli.
@export var debug_mode: bool = false

func _init() -> void:
	ability_name = "Doskok z Uderzeniem"
	cooldown = 12.0
	min_range = 0.0
	max_range = DEFAULT_DASH_MAX_RANGE
	damage_category = Effect.EffectCategory.PHYSICAL_DAMAGE

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	if debug_mode:
		print("[DashStrike] %s rozpoczyna doskok na %s!" % [attacker.name, target.name])

	# 1. Zwrócenie się w stronę celu przed doskokiem
	var aim_direction: Vector2 = attacker.global_position.direction_to(target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	orient_towards(attacker, aim_direction)

	# 2. Wyznaczenie bezpiecznej trasy doskoku (Edge-to-Edge z kontrolą kolizji ze ścianą)
	var original_pos: Vector2 = attacker.global_position
	var edge_distance: float = get_edge_distance(attacker, target)
	var actual_dash_distance: float = minf(dash_distance, edge_distance)
	var move_vec: Vector2 = aim_direction * actual_dash_distance

	var col: KinematicCollision2D = attacker.move_and_collide(move_vec, true)
	var forward_pos: Vector2 = original_pos + move_vec
	if col != null:
		forward_pos = original_pos + col.get_travel()
		if debug_mode:
			print("[DashStrike] Ściana na drodze! Skracam doskok do %.1f px." % col.get_travel().length())

	var dash_in_duration: float = cast_time * HALF_CAST_TIME_FACTOR if return_to_start_position else cast_time
	var dash_in_tween: Tween = create_kinematic_dash_tween(
		attacker,
		forward_pos,
		dash_in_duration,
		Tween.TRANS_SINE,
		Tween.EASE_OUT
	)

	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl)
		return
	await dash_in_tween.finished
	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl)
		return

	# 3. Sprawdzenie trafienia w szczycie doskoku i nałożenie efektów + komponentów
	if is_instance_valid(target) and not target.is_dead and not target.is_respawning:
		var post_dash_edge_dist: float = get_edge_distance(attacker, target)
		var hit_threshold: float = max_range + hit_distance_leeway
		var is_hit: bool = post_dash_edge_dist <= hit_threshold

		if debug_mode:
			_spawn_debug_visual(attacker, target, hit_threshold, is_hit, post_dash_edge_dist)

		if is_hit and can_affect_target(attacker, target, false, true, false):
			attacker.play_unarmed_attack_animation(target.global_position)
			var hit_effects: Array[Effect] = build_hit_effects(attacker)
			apply_effects_to_target(attacker, target, hit_effects, attacker.global_position)
			notify_components_area_detonated(attacker, target.global_position, hit_threshold)
			notify_components_target_hit(attacker, target, attacker.global_position)
			CombatVFXHelper.spawn_impact_sparks(
				attacker,
				target.global_position,
				aim_direction,
				impact_vfx_color,
				IMPACT_SPARK_COUNT,
				IMPACT_SPARK_RADIUS_PX
			)

	# 4. Opcjonalny powrót na pozycję startową
	if return_to_start_position and is_caster_active(attacker):
		var dash_back_tween: Tween = create_kinematic_dash_tween(
			attacker,
			original_pos,
			dash_in_duration,
			Tween.TRANS_SINE,
			Tween.EASE_IN
		)
		await dash_back_tween.finished

	_finish_cast(attacker, combat_ctrl)

func _spawn_debug_visual(
	attacker: CharacterEntity,
	target: CharacterEntity,
	hit_threshold: float,
	is_hit: bool,
	edge_dist: float
) -> void:
	print("[DashStrike] Krawędzie oddalone o %d px (Tolerancja: %.1f px)." % [int(round(edge_dist)), hit_threshold])
	var debug_vis := DashStrikeDebugVisual.new()
	var total_rad: float = hit_threshold + CharacterEntity.get_effective_radius_of(attacker) + CharacterEntity.get_effective_radius_of(target)
	debug_vis.setup(total_rad, is_hit, target.global_position, DEBUG_VISUAL_Z_INDEX)
	spawn_ability_node(attacker, debug_vis, attacker.global_position)

## Bezpiecznie kończy rzucanie zdolności (parametry Variant chronią przed błędem 'previously freed' po await).
func _finish_cast(attacker: Variant, combat_ctrl: Variant) -> void:
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Graficzny Debugger Doskoku (opcjonalny)
# ==============================================================================
class DashStrikeDebugVisual extends Node2D:
	const DEBUG_DURATION_SEC: float = 1.5
	const MIN_DURATION_SEC: float = 0.01
	const FILL_ALPHA_MULT: float = 0.20
	const OUTLINE_ALPHA_MULT: float = 0.80
	const RING_POINTS: int = 32
	const LINE_WIDTH_PX: float = 2.0
	const TARGET_DOT_RADIUS_PX: float = 4.0

	var _radius: float = 0.0
	var _elapsed: float = 0.0
	var _hit_success: bool = false
	var _target_pos: Vector2 = Vector2.ZERO

	func setup(radius: float, hit_success: bool, target_pos: Vector2, z_layer: int) -> void:
		_radius = radius
		_hit_success = hit_success
		_target_pos = target_pos
		z_as_relative = false
		z_index = z_layer

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()
		if _elapsed >= DEBUG_DURATION_SEC:
			queue_free()

	func _draw() -> void:
		var alpha: float = clampf(1.0 - (_elapsed / maxf(MIN_DURATION_SEC, DEBUG_DURATION_SEC)), 0.0, 1.0)
		var base_col: Color = Color.GREEN if _hit_success else Color.RED
		var fill_color := Color(base_col.r, base_col.g, base_col.b, alpha * FILL_ALPHA_MULT)
		var outline_color := Color(base_col.r, base_col.g, base_col.b, alpha * OUTLINE_ALPHA_MULT)

		draw_circle(Vector2.ZERO, _radius, fill_color)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, RING_POINTS, outline_color, LINE_WIDTH_PX, true)

		if _target_pos != Vector2.ZERO:
			var local_target: Vector2 = to_local(_target_pos)
			draw_line(Vector2.ZERO, local_target, outline_color, LINE_WIDTH_PX, true)
			draw_circle(local_target, TARGET_DOT_RADIUS_PX, outline_color)
