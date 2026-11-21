extends AIAbility
class_name SpinSlashAbility
## Uniwersalny archetyp obrotowego cięcia obszarowego z opcjonalnym doskokiem i powrotem (SOLID - SRP / OCP / DRY).
## Pozwala tworzyć w plikach .tres np. Wirujący Ogon, Wirowe Cięcie Mieczem lub Huragan Mrozu —
## wszystkie obrażenia, stun, odrzut i statusy pochodzą z AttackData, on_hit_effects i components.

#region Stałe Domenowe (Brak magicznych liczb)
const HIT_DETECTION_TIME_RATIO: float = 0.30
const MAX_SLASH_TARGETS: int = 24
const DEFAULT_SLASH_MAX_RANGE: float = 120.0
const IMPACT_SPARK_COUNT: int = 8
const IMPACT_SPARK_RADIUS_PX: float = 28.0
#endregion

@export_category("Archetyp: Obrotowe Cięcie Obszarowe (SpinSlashAbility)")

@export_group("Czasy Trwania")
## Czas telegrafowania (odwrócenia się / zamachu) przed doskokiem (w sekundach).
@export_range(0.05, 3.0, 0.05) var telegraph_time: float = 1.0
## Czas trwania doskoku w kierunku celu (w sekundach; 0.0 pomija doskok).
@export_range(0.0, 2.0, 0.05) var dash_forward_time: float = 0.5
## Czas trwania obrotu (bączka) i wielowarstwowej smugi cięcia (w sekundach).
@export_range(0.1, 3.0, 0.05) var slash_duration: float = 1.5
## Czas powrotu na pozycję startową (używany tylko, gdy return_to_original_position == true).
@export_range(0.1, 2.0, 0.05) var dash_return_time: float = 0.4

@export_group("Doskok, Hitbox i Rotacja")
## Dystans (w pikselach), na jaki postać doskakuje w stronę celu przed obrotem.
@export_range(0.0, 400.0, 10.0) var dash_distance: float = 60.0
## Czy po zakończeniu cięcia postać ma wrócić na pozycję startową?
@export var return_to_original_position: bool = false
## Promień fizycznego obszaru rażenia (AoE) oraz rysowanej smugi cięcia (w pikselach).
@export_range(20.0, 400.0, 10.0) var slash_radius: float = 120.0
## Liczba pełnych obrotów postaci podczas cięcia (1.5 = 540°, kończy twarzą do gracza).
@export_range(0.5, 4.0, 0.5) var spin_rotations: float = 1.5
## Czy podczas fazy telegrafowania postać ma odwrócić się tyłem (np. zamach ogonem), czy patrzeć na cel?
@export var turn_away_during_telegraph: bool = true
## Czy cięcie ma oddziaływać również na sojuszników (friendly fire)?
@export var friendly_fire: bool = false

@export_group("Wizualizacje Cięcia i Warstwy (VFX)")
## Warstwa renderowania (Z-Index) smugi cięcia (domyślnie GameLayers.FX).
@export var slash_z_index: int = GameLayers.FX
## Główny kolor smugi zostawianej w powietrzu podczas obrotu.
@export var slash_color: Color = Color(0.20, 0.90, 0.30, 0.65)
## Kolor jasnego, ostrego rdzenia cięcia.
@export var slash_core_color: Color = Color(1.0, 1.0, 1.0, 0.85)

func _init() -> void:
	ability_name = "Obrotowe Cięcie"
	cooldown = 7.0
	min_range = 0.0
	max_range = DEFAULT_SLASH_MAX_RANGE
	damage_category = Effect.EffectCategory.PHYSICAL_DAMAGE

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	var can_rotate: bool = can_entity_rotate(attacker)
	var start_position: Vector2 = attacker.global_position
	var aim_direction: Vector2 = attacker.global_position.direction_to(target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var telegraph_dir: Vector2 = -aim_direction if turn_away_during_telegraph else aim_direction

	# =========================================================
	# FAZA 1: TELEGRAFOWANIE (ZAMACH)
	# =========================================================
	if can_rotate:
		var rot_tween: Tween = attacker.create_tracked_tween()
		rot_tween.tween_property(attacker, "rotation", telegraph_dir.angle(), telegraph_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		orient_towards(attacker, telegraph_dir)

	await attacker.get_tree().create_timer(telegraph_time).timeout
	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl, null)
		return

	# =========================================================
	# FAZA 2: BEZPIECZNY KINEMATYCZNY DOSKOK
	# =========================================================
	if dash_distance > 0.0 and dash_forward_time > 0.0 and is_instance_valid(target):
		aim_direction = attacker.global_position.direction_to(target.global_position)
		if aim_direction != Vector2.ZERO:
			var original_pos: Vector2 = attacker.global_position
			var edge_distance: float = get_edge_distance(attacker, target)
			var actual_dash_distance: float = minf(dash_distance, edge_distance)
			var move_vec: Vector2 = aim_direction * actual_dash_distance

			var col: KinematicCollision2D = attacker.move_and_collide(move_vec, true)
			var forward_pos: Vector2 = original_pos + (col.get_travel() if col != null else move_vec)
			create_kinematic_dash_tween(attacker, forward_pos, dash_forward_time, Tween.TRANS_EXPO, Tween.EASE_OUT)

			await attacker.get_tree().create_timer(dash_forward_time).timeout
			if not is_caster_active(attacker):
				_finish_cast(attacker, combat_ctrl, null)
				return

	# =========================================================
	# FAZA 3: OBRÓT, WIELOWARSTWOWA SMUGA I UDERZENIE AoE
	# =========================================================
	var total_spin_angle: float = TAU * spin_rotations

	var slash_visual := SpinSlashVisual.new()
	slash_visual.setup(attacker, slash_radius, slash_color, slash_core_color, slash_duration, total_spin_angle, slash_z_index)
	spawn_ability_node(attacker, slash_visual, attacker.global_position)

	var spin_tween: Tween = attacker.create_tracked_tween()
	if can_rotate:
		spin_tween.tween_property(attacker, "rotation", attacker.rotation + total_spin_angle, slash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		spin_tween.tween_method(
			func(angle_offset: float):
				if is_caster_active(attacker) and attacker.has_method("_update_sprite_direction"):
					attacker._update_sprite_direction(telegraph_dir.rotated(angle_offset)),
			0.0,
			total_spin_angle,
			slash_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await attacker.get_tree().create_timer(slash_duration * HIT_DETECTION_TIME_RATIO).timeout
	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl, slash_visual)
		return

	_perform_spin_hit_detection(attacker)

	var remaining_spin_time: float = slash_duration * (1.0 - HIT_DETECTION_TIME_RATIO)
	await attacker.get_tree().create_timer(remaining_spin_time).timeout
	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl, slash_visual)
		return

	# =========================================================
	# FAZA 4: OPCJONALNY POWRÓT NA POZYCJĘ STARTOWĄ
	# =========================================================
	if return_to_original_position:
		var ret_tween: Tween = create_kinematic_dash_tween(
			attacker,
			start_position,
			dash_return_time,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT
		)
		await ret_tween.finished
		if not is_caster_active(attacker):
			_finish_cast(attacker, combat_ctrl, null)
			return

	if is_instance_valid(target):
		orient_towards(attacker, attacker.global_position.direction_to(target.global_position))

	_finish_cast(attacker, combat_ctrl, null)

## Wykrywa cele w promieniu slash_radius i aplikuje efekty z jednolitego kontraktu AIAbility + komponenty.
func _perform_spin_hit_detection(attacker: CharacterEntity) -> void:
	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = slash_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, attacker.global_position)
	query.exclude = [attacker.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, MAX_SLASH_TARGETS)
	var hit_effects: Array[Effect] = build_hit_effects(attacker)

	CombatVFXHelper.spawn_shockwave(attacker, attacker.global_position, slash_radius, slash_color, 0.24, slash_z_index, 0.14)
	notify_components_area_detonated(attacker, attacker.global_position, slash_radius)

	for hit in hits:
		var col: Node2D = hit["collider"] as Node2D
		if not can_affect_target(attacker, col, friendly_fire, true, false):
			continue
		if apply_effects_to_target(attacker, col, hit_effects, attacker.global_position):
			CombatVFXHelper.spawn_impact_sparks(
				attacker,
				col.global_position,
				attacker.global_position.direction_to(col.global_position),
				slash_core_color,
				IMPACT_SPARK_COUNT,
				IMPACT_SPARK_RADIUS_PX
			)
		notify_components_target_hit(attacker, col, attacker.global_position)

## Bezpiecznie kończy rzucanie zdolności (parametry Variant chronią przed błędem 'previously freed' po await).
func _finish_cast(attacker: Variant, combat_ctrl: Variant, slash_visual: Variant) -> void:
	if is_instance_valid(slash_visual) and slash_visual is Node:
		(slash_visual as Node).queue_free()
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Wielowarstwowy ślad obrotowego cięcia w powietrzu
# ==============================================================================
class SpinSlashVisual extends Node2D:
	const MIN_DURATION_SEC: float = 0.01
	const ARC_POINTS: int = 36
	const ARC_START_RAD: float = -PI
	const ARC_END_RAD: float = PI * 0.65
	const START_RADIUS_MULT: float = 0.45
	const END_RADIUS_MULT: float = 0.96
	const OUTER_GLOW_WIDTH_MULT: float = 0.56
	const MAIN_ARC_WIDTH_MULT: float = 0.34
	const CORE_ARC_WIDTH_MULT: float = 0.12
	const OUTER_GLOW_ALPHA_MULT: float = 0.35
	const TIP_GLOW_RADIUS_MULT: float = 0.10

	var _target_node: Node2D = null
	var _radius: float = 80.0
	var _color: Color = Color.GREEN
	var _core_color: Color = Color.WHITE
	var _duration: float = 0.5
	var _total_angle: float = TAU
	var _elapsed: float = 0.0

	func setup(
		target: Node2D,
		radius: float,
		color: Color,
		core_color: Color,
		duration: float,
		total_angle: float,
		z_layer: int
	) -> void:
		_target_node = target
		_radius = radius
		_color = color
		_core_color = core_color
		_duration = maxf(MIN_DURATION_SEC, duration)
		_total_angle = total_angle
		z_as_relative = false
		z_index = z_layer

	func _ready() -> void:
		rotation = randf_range(0.0, TAU)

	func _process(delta: float) -> void:
		if not is_instance_valid(_target_node):
			queue_free()
			return

		global_position = _target_node.global_position
		_elapsed += delta
		rotation += (_total_angle / _duration) * delta
		queue_redraw()
		if _elapsed >= _duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
		var current_radius: float = lerpf(_radius * START_RADIUS_MULT, _radius * END_RADIUS_MULT, progress)
		var alpha: float = 1.0 - progress

		var glow_col := Color(_color.r, _color.g, _color.b, _color.a * OUTER_GLOW_ALPHA_MULT * alpha)
		var main_col := Color(_color.r, _color.g, _color.b, alpha)
		var core_col := Color(_core_color.r, _core_color.g, _core_color.b, alpha)

		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, glow_col, current_radius * OUTER_GLOW_WIDTH_MULT * alpha, true)
		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, main_col, current_radius * MAIN_ARC_WIDTH_MULT * alpha, true)
		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, core_col, current_radius * CORE_ARC_WIDTH_MULT * alpha, true)

		# Jasna krawędź prowadząca na czubku ostrza
		var tip_pos: Vector2 = Vector2.from_angle(ARC_END_RAD) * current_radius
		draw_circle(tip_pos, current_radius * TIP_GLOW_RADIUS_MULT * alpha, core_col)
