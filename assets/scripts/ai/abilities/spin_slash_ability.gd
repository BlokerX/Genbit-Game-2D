extends AIAbility
class_name SpinSlashAbility
## Uniwersalny archetyp obrotowego cięcia obszarowego z opcjonalnym doskokiem i powrotem (SOLID - SRP / OCP / DRY).
## Skaluje efektywny promień cięcia o rzeczywisty promień ciała rzucającego (include_caster_radius),
## dzięki czemu wielcy bossowie (np. 3x skala) tną wyraźnie na zewnątrz swojej sylwetki!

#region Stałe Domenowe (Brak magicznych liczb)
const HIT_DETECTION_TIME_RATIO: float = 0.30
const MAX_SLASH_TARGETS: int = 24
const DEFAULT_SLASH_MAX_RANGE: float = 120.0
const IMPACT_SPARK_COUNT: int = 8
const IMPACT_SPARK_RADIUS_PX: float = 28.0
const MIN_VISUAL_BAND_WIDTH_PX: float = 18.0
const MAX_VISUAL_BAND_WIDTH_PX: float = 68.0
const VISUAL_BAND_WIDTH_RATIO: float = 0.42
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
## Zasięg cięcia (w pikselach). Gdy include_caster_radius == true, liczony jest od KRAWĘDZI ciała rzucającego (spójne z max_range!).
@export_range(20.0, 400.0, 10.0) var slash_radius: float = 120.0
## Jeśli true (domyślnie), do slash_radius doliczany jest efektywny promień ciała rzucającego (Information Expert dla bossów 3x).
@export var include_caster_radius: bool = true
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

	var attacker_ref: WeakRef = weakref(attacker)
	var target_ref: WeakRef = weakref(target)
	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	var combat_ctrl_ref: WeakRef = weakref(combat_ctrl) if combat_ctrl != null else null
	notify_components_cast_started(attacker, target)

	var can_rotate: bool = can_entity_rotate(attacker)
	var start_position: Vector2 = attacker.global_position
	var aim_direction: Vector2 = attacker.global_position.direction_to(target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var telegraph_dir: Vector2 = -aim_direction if turn_away_during_telegraph else aim_direction

	var scene_tree: SceneTree = attacker.get_tree()
	if scene_tree == null:
		_finish_cast(attacker_ref, combat_ctrl_ref, null)
		return

	# =========================================================
	# FAZA 1: TELEGRAFOWANIE (ZAMACH)
	# =========================================================
	if can_rotate:
		var rot_tween: Tween = attacker.create_tracked_tween()
		rot_tween.tween_property(attacker, "rotation", telegraph_dir.angle(), telegraph_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		orient_towards(attacker, telegraph_dir)

	await scene_tree.create_timer(telegraph_time).timeout
	if not is_caster_active(attacker_ref.get_ref()):
		_finish_cast(attacker_ref, combat_ctrl_ref, null)
		return

	# =========================================================
	# FAZA 2: BEZPIECZNY KINEMATYCZNY DOSKOK
	# =========================================================
	var live_attacker: CharacterEntity = attacker_ref.get_ref() as CharacterEntity
	var live_target: Variant = target_ref.get_ref()
	if dash_distance > 0.0 and dash_forward_time > 0.0 and is_instance_valid(live_target) and live_target is Node2D:
		aim_direction = live_attacker.global_position.direction_to((live_target as Node2D).global_position)
		if aim_direction != Vector2.ZERO:
			var original_pos: Vector2 = live_attacker.global_position
			var edge_distance: float = get_edge_distance(live_attacker, live_target)
			var actual_dash_distance: float = minf(dash_distance, edge_distance)
			var move_vec: Vector2 = aim_direction * actual_dash_distance

			var col: KinematicCollision2D = live_attacker.move_and_collide(move_vec, true)
			var forward_pos: Vector2 = original_pos + (col.get_travel() if col != null else move_vec)
			create_kinematic_dash_tween(live_attacker, forward_pos, dash_forward_time, Tween.TRANS_EXPO, Tween.EASE_OUT)

			await scene_tree.create_timer(dash_forward_time).timeout
			if not is_caster_active(attacker_ref.get_ref()):
				_finish_cast(attacker_ref, combat_ctrl_ref, null)
				return

	# =========================================================
	# FAZA 3: OBRÓT, WIELOWARSTWOWA SMUGA I UDERZENIE AoE
	# =========================================================
	live_attacker = attacker_ref.get_ref() as CharacterEntity
	var effective_radius: float = _get_effective_slash_radius(live_attacker)
	var visual_band_width: float = clampf(
		slash_radius * VISUAL_BAND_WIDTH_RATIO,
		MIN_VISUAL_BAND_WIDTH_PX,
		MAX_VISUAL_BAND_WIDTH_PX
	)
	var total_spin_angle: float = TAU * spin_rotations

	var slash_visual := SpinSlashVisual.new()
	slash_visual.setup(
		live_attacker,
		effective_radius,
		visual_band_width,
		slash_color,
		slash_core_color,
		slash_duration,
		total_spin_angle,
		slash_z_index
	)
	var visual_ref: WeakRef = weakref(slash_visual)
	spawn_ability_node(live_attacker, slash_visual, live_attacker.global_position)

	var spin_tween: Tween = live_attacker.create_tracked_tween()
	if can_rotate:
		spin_tween.tween_property(live_attacker, "rotation", live_attacker.rotation + total_spin_angle, slash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		spin_tween.tween_method(
			func(angle_offset: float):
				var cur_caster: Variant = attacker_ref.get_ref()
				if is_caster_active(cur_caster) and (cur_caster as Node).has_method("_update_sprite_direction"):
					(cur_caster as Node).call("_update_sprite_direction", telegraph_dir.rotated(angle_offset)),
			0.0,
			total_spin_angle,
			slash_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await scene_tree.create_timer(slash_duration * HIT_DETECTION_TIME_RATIO).timeout
	if not is_caster_active(attacker_ref.get_ref()):
		_finish_cast(attacker_ref, combat_ctrl_ref, visual_ref)
		return

	_perform_spin_hit_detection(attacker_ref.get_ref() as CharacterEntity, effective_radius)

	var remaining_spin_time: float = slash_duration * (1.0 - HIT_DETECTION_TIME_RATIO)
	await scene_tree.create_timer(remaining_spin_time).timeout
	if not is_caster_active(attacker_ref.get_ref()):
		_finish_cast(attacker_ref, combat_ctrl_ref, visual_ref)
		return

	# =========================================================
	# FAZA 4: OPCJONALNY POWRÓT NA POZYCJĘ STARTOWĄ
	# =========================================================
	live_attacker = attacker_ref.get_ref() as CharacterEntity
	if return_to_original_position:
		var ret_tween: Tween = create_kinematic_dash_tween(
			live_attacker,
			start_position,
			dash_return_time,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT
		)
		await ret_tween.finished
		if not is_caster_active(attacker_ref.get_ref()):
			_finish_cast(attacker_ref, combat_ctrl_ref, null)
			return
		live_attacker = attacker_ref.get_ref() as CharacterEntity

	live_target = target_ref.get_ref()
	if is_instance_valid(live_target) and live_target is Node2D:
		orient_towards(live_attacker, live_attacker.global_position.direction_to((live_target as Node2D).global_position))

	_finish_cast(attacker_ref, combat_ctrl_ref, null)

## Oblicza rzeczywisty promień rażenia od środka rzucającego (z uwzględnieniem skali bossa).
func _get_effective_slash_radius(attacker: CharacterEntity) -> float:
	if not include_caster_radius:
		return slash_radius
	return CharacterEntity.get_effective_radius_of(attacker) + slash_radius

## Wykrywa cele w promieniu effective_radius i aplikuje efekty z jednolitego kontraktu AIAbility + komponenty.
func _perform_spin_hit_detection(attacker: CharacterEntity, effective_radius: float) -> void:
	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = effective_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, attacker.global_position)
	query.exclude = [attacker.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, MAX_SLASH_TARGETS)
	var hit_effects: Array[Effect] = build_hit_effects(attacker)

	CombatVFXHelper.spawn_shockwave(attacker, attacker.global_position, effective_radius, slash_color, 0.24, slash_z_index, 0.14)
	notify_components_area_detonated(attacker, attacker.global_position, effective_radius)

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

## Bezpiecznie kończy rzucanie zdolności (WeakRef chroni przed błędem 'previously freed' po await).
func _finish_cast(attacker_ref: WeakRef, combat_ctrl_ref: WeakRef, visual_ref: WeakRef) -> void:
	if visual_ref != null:
		var live_visual: Variant = visual_ref.get_ref()
		if is_instance_valid(live_visual) and live_visual is Node:
			(live_visual as Node).queue_free()
	if combat_ctrl_ref != null:
		var live_ctrl: Variant = combat_ctrl_ref.get_ref()
		if is_instance_valid(live_ctrl) and live_ctrl is AICombatController:
			(live_ctrl as AICombatController).is_casting_ability = false
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	notify_components_cast_finished(live_attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Wielowarstwowy ślad obrotowego cięcia (samooczyszczający się)
# ==============================================================================
class SpinSlashVisual extends Node2D:
	const MIN_DURATION_SEC: float = 0.01
	const ARC_POINTS: int = 44
	const ARC_START_RAD: float = -PI
	const ARC_END_RAD: float = PI * 0.65
	const START_RADIUS_MULT: float = 0.72
	const END_RADIUS_MULT: float = 1.00
	const OUTER_GLOW_WIDTH_MULT: float = 1.45
	const MAIN_ARC_WIDTH_MULT: float = 0.90
	const CORE_ARC_WIDTH_MULT: float = 0.34
	const OUTER_GLOW_ALPHA_MULT: float = 0.35
	const TIP_GLOW_WIDTH_MULT: float = 0.42

	var _caster_ref: WeakRef = null
	var _radius: float = 120.0
	var _band_width: float = 36.0
	var _color: Color = Color.GREEN
	var _core_color: Color = Color.WHITE
	var _duration: float = 0.5
	var _total_angle: float = TAU
	var _elapsed: float = 0.0

	func setup(
		caster: Node2D,
		radius: float,
		band_width: float,
		color: Color,
		core_color: Color,
		duration: float,
		total_angle: float,
		z_layer: int
	) -> void:
		_caster_ref = weakref(caster) if is_instance_valid(caster) else null
		_radius = radius
		_band_width = band_width
		_color = color
		_core_color = core_color
		_duration = maxf(MIN_DURATION_SEC, duration)
		_total_angle = total_angle
		z_as_relative = false
		z_index = z_layer

	func _ready() -> void:
		rotation = randf_range(0.0, TAU)

	func _process(delta: float) -> void:
		var live_caster: Variant = _caster_ref.get_ref() if _caster_ref != null else null
		if not AIAbility.is_caster_active(live_caster):
			queue_free()
			return

		global_position = (live_caster as Node2D).global_position
		_elapsed += delta
		rotation += (_total_angle / _duration) * delta
		queue_redraw()
		if _elapsed >= _duration:
			queue_free()

	func _draw() -> void:
		var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
		var current_radius: float = lerpf(_radius * START_RADIUS_MULT, _radius * END_RADIUS_MULT, progress)
		var alpha: float = 1.0 - progress
		var eff_band: float = _band_width * lerpf(1.0, 0.25, progress)

		var glow_col := Color(_color.r, _color.g, _color.b, _color.a * OUTER_GLOW_ALPHA_MULT * alpha)
		var main_col := Color(_color.r, _color.g, _color.b, alpha)
		var core_col := Color(_core_color.r, _core_color.g, _core_color.b, alpha)

		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, glow_col, eff_band * OUTER_GLOW_WIDTH_MULT, true)
		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, main_col, eff_band * MAIN_ARC_WIDTH_MULT, true)
		draw_arc(Vector2.ZERO, current_radius, ARC_START_RAD, ARC_END_RAD, ARC_POINTS, core_col, eff_band * CORE_ARC_WIDTH_MULT, true)

		var tip_pos: Vector2 = Vector2.from_angle(ARC_END_RAD) * current_radius
		draw_circle(tip_pos, eff_band * TIP_GLOW_WIDTH_MULT, core_col)
