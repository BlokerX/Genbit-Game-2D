extends AIAbility
class_name ZoneBarrageAbility
## Uniwersalny archetyp ostrzału wieloma strefami TelegraphedAOE wewnątrz wielkiej strefy zagrożenia (SOLID - SRP / OCP / DRY).
## Pozwala tworzyć w plikach .tres np. Wirujący Deszcz Kwasu, Deszcz Meteorytów, Grad Mrozu lub Deszcz Oczyszczenia —
## wszystkie obrażenia, stun, odrzut i statusy pochodzą wyłącznie z AttackData, on_hit_effects i components.

## Wzór rozmieszczania pojedynczych stref wewnątrz głównego okręgu ostrzału.
enum BarragePattern {
	SPIRAL_RINGS,     ## 1 strefa śledzi ruch celu, a pozostałe tworzą wirujące pierścienie.
	RANDOM_SCATTER,   ## Losowe rozrzucenie stref w obrębie okręgu (+ opcjonalna strefa na celu).
	CONCENTRIC_BURST  ## Równomierny pierścień stref rozchodzący się cyklicznie od środka na zewnątrz.
}

#region Stałe Domenowe (Brak magicznych liczb)
const OUTER_RING_FACTOR: float = 0.80
const INNER_RING_FACTOR: float = 0.40
const PATTERN_ROTATION_STEP_RAD: float = PI / 4.0
const ORIENT_LERP_WEIGHT: float = 0.50
const DEFAULT_BARRAGE_MAX_RANGE: float = 600.0
#endregion

@export_category("Archetyp: Ostrzał Strefowy (ZoneBarrageAbility)")

@export_group("Czas, Wzór i Zasięg Ostrzału")
## Całkowity czas trwania ostrzału strefami (w sekundach).
@export_range(0.5, 20.0, 0.5) var barrage_duration: float = 6.0
## Odstęp pomiędzy kolejnymi falami spadających stref (w sekundach).
@export_range(0.1, 3.0, 0.05) var spawn_interval: float = 0.7
## Liczba stref pojawiających się w każdej fali.
@export_range(1, 16, 1) var zones_per_tick: int = 5
## Wzór rozmieszczania stref wewnątrz giga-strefy.
@export var pattern: BarragePattern = BarragePattern.SPIRAL_RINGS
## Czy pierwsza strefa z każdej fali ma celować bezpośrednio w przewidywaną pozycję celu?
@export var aim_first_zone_at_target: bool = true
## Promień całej giga-strefy ostrzału (w pikselach).
@export_range(150.0, 2000.0, 25.0) var barrage_radius: float = 1000.0
## Promień pojedynczej strefy rażenia TelegraphedAOE (w pikselach).
@export_range(20.0, 300.0, 5.0) var sub_zone_radius: float = 65.0
## Czas ładowania pojedynczej strefy przed wybuchem (w sekundach).
@export_range(0.2, 4.0, 0.1) var sub_zone_cast_time: float = 1.2
## Współczynnik przewidywania ruchu celu dla strefy celowanej (w sekundach).
@export_range(0.0, 2.0, 0.1) var prediction_time: float = 0.7
## Czy strefy mają ranić również sojuszników (friendly fire)?
@export var friendly_fire: bool = false
## Jeśli true (domyślnie), śmierć rzucającego natychmiast przerywa ostrzał i usuwa niewybuchłe strefy.
@export var cancel_on_caster_death: bool = true

@export_group("Wizualizacje i Warstwy (VFX)")
## Warstwa renderowania (Z-Index) dla wielkiej strefy zagrożenia (domyślnie GameLayers.FLOOR_HAZARD).
@export var barrage_z_index: int = GameLayers.FLOOR_HAZARD
## Warstwa renderowania (Z-Index) dla pojedynczych stref rażenia (domyślnie GameLayers.HAZARD).
@export var sub_zone_z_index: int = GameLayers.HAZARD
## Kolor półprzezroczystego wypełnienia wielkiej strefy ostrzału.
@export var barrage_fill_color: Color = Color(0.82, 0.0, 0.329, 0.24)
## Kolor pulsującego obramowania i wirujących znaczników wielkiej strefy.
@export var barrage_outline_color: Color = Color(1.0, 0.12, 0.18, 0.72)
## Kolor pojedynczych stref ostrzegawczych TelegraphedAOE.
@export var sub_zone_danger_color: Color = Color(1.0, 0.624, 0.102, 0.612)

func _init() -> void:
	ability_name = "Ostrzał Strefowy"
	cooldown = 15.0
	min_range = 0.0
	max_range = DEFAULT_BARRAGE_MAX_RANGE
	damage_category = Effect.EffectCategory.POISON_ACID

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var attacker_ref: WeakRef = weakref(attacker)
	var target_ref: WeakRef = weakref(target)
	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	var combat_ctrl_ref: WeakRef = weakref(combat_ctrl) if combat_ctrl != null else null
	notify_components_cast_started(attacker, target)

	var scene_tree: SceneTree = attacker.get_tree()
	if scene_tree == null:
		_finish_cast(attacker_ref, combat_ctrl_ref, null, true)
		return

	# 1. Zamrożenie epicentrum i utworzenie wielkiego okręgu ostrzegawczego
	var epicenter: Vector2 = target.global_position
	var danger_zone := BarrageZoneIndicator.new()
	danger_zone.setup(
		attacker,
		barrage_radius,
		barrage_duration,
		barrage_fill_color,
		barrage_outline_color,
		cancel_on_caster_death,
		barrage_z_index
	)
	var zone_ref: WeakRef = weakref(danger_zone)
	spawn_ability_node(attacker, danger_zone, epicenter)

	var elapsed: float = 0.0
	var tick_index: int = 0
	var pattern_angle_offset: float = 0.0

	while elapsed < barrage_duration:
		var live_attacker: Variant = attacker_ref.get_ref()
		var live_target: Variant = target_ref.get_ref()
		if not is_caster_active(live_attacker) or not is_instance_valid(live_target) or not (live_target is Node2D):
			_finish_cast(attacker_ref, combat_ctrl_ref, zone_ref, cancel_on_caster_death)
			return

		var caster: CharacterEntity = live_attacker as CharacterEntity
		var tgt: Node2D = live_target as Node2D

		# 2. Przewidywanie ruchu celu ograniczone do wnętrza giga-okręgu
		var predicted_pos: Vector2 = tgt.global_position
		if "velocity" in tgt:
			predicted_pos += tgt.velocity * prediction_time

		var max_dist: float = maxf(0.0, barrage_radius - sub_zone_radius)
		if epicenter.distance_to(predicted_pos) > max_dist:
			predicted_pos = epicenter + (epicenter.direction_to(predicted_pos) * max_dist)

		orient_towards(caster, caster.global_position.direction_to(predicted_pos), ORIENT_LERP_WEIGHT)

		# 3. Spawnowanie stref pojedynczej fali z efektami z jednolitego kontraktu AIAbility
		var wave_effects: Array[Effect] = build_hit_effects(caster)
		var live_danger_zone: Variant = zone_ref.get_ref()

		for i in range(zones_per_tick):
			var drop_pos: Vector2 = _calculate_sub_zone_position(
				i,
				epicenter,
				predicted_pos,
				max_dist,
				pattern_angle_offset,
				tick_index
			)
			_spawn_single_sub_zone(caster, attacker_ref, live_danger_zone, drop_pos, wave_effects)

		pattern_angle_offset += PATTERN_ROTATION_STEP_RAD
		tick_index += 1
		elapsed += spawn_interval

		await scene_tree.create_timer(spawn_interval).timeout

	_finish_cast(attacker_ref, combat_ctrl_ref, zone_ref, false)

func _calculate_sub_zone_position(
	index: int,
	epicenter: Vector2,
	predicted_pos: Vector2,
	max_dist: float,
	angle_offset: float,
	tick_index: int
) -> Vector2:
	if index == 0 and aim_first_zone_at_target:
		return predicted_pos

	var non_aimed_count: int = maxi(1, zones_per_tick - (1 if aim_first_zone_at_target else 0))
	var pattern_idx: int = index - (1 if aim_first_zone_at_target else 0)

	match pattern:
		BarragePattern.SPIRAL_RINGS:
			var fraction: float = float(pattern_idx) / float(non_aimed_count)
			var angle: float = (fraction * TAU) + angle_offset
			var ring_dist: float = max_dist * (OUTER_RING_FACTOR if (tick_index % 2 == 0) else INNER_RING_FACTOR)
			return epicenter + (Vector2.from_angle(angle) * ring_dist)

		BarragePattern.RANDOM_SCATTER:
			var rand_angle: float = randf_range(0.0, TAU)
			var rand_dist: float = sqrt(randf()) * max_dist
			return epicenter + (Vector2.from_angle(rand_angle) * rand_dist)

		BarragePattern.CONCENTRIC_BURST:
			var fraction: float = float(pattern_idx) / float(non_aimed_count)
			var angle: float = (fraction * TAU) + angle_offset
			var ring_ratio: float = 0.25 + (0.70 * fmod(float(tick_index) * 0.33, 1.0))
			return epicenter + (Vector2.from_angle(angle) * (max_dist * ring_ratio))

	return predicted_pos

func _spawn_single_sub_zone(
	caster: CharacterEntity,
	attacker_ref: WeakRef,
	danger_zone: Variant,
	drop_pos: Vector2,
	wave_effects: Array[Effect]
) -> void:
	var aoe := TelegraphedAOE.new()
	aoe.setup(drop_pos, sub_zone_radius, sub_zone_cast_time, wave_effects, caster)
	aoe.friendly_fire = friendly_fire
	aoe.cancel_on_caster_death = cancel_on_caster_death
	aoe.z_index = sub_zone_z_index
	aoe.z_as_relative = false
	aoe.danger_color = sub_zone_danger_color
	aoe.on_detonated_callback = func(origin_pos: Vector2, rad: float) -> void:
		notify_components_area_detonated(attacker_ref.get_ref(), origin_pos, rad)
	aoe.on_target_hit_callback = func(hit_target: Node2D, origin_pos: Vector2) -> void:
		notify_components_target_hit(attacker_ref.get_ref(), hit_target, origin_pos)

	if is_instance_valid(danger_zone) and danger_zone is Node:
		(danger_zone as Node).add_child(aoe)
		aoe.global_position = drop_pos
	else:
		spawn_ability_node(caster, aoe, drop_pos)

func _finish_cast(
	attacker_ref: WeakRef,
	combat_ctrl_ref: WeakRef,
	zone_ref: WeakRef,
	force_destroy_zone: bool
) -> void:
	if force_destroy_zone and zone_ref != null:
		var live_zone: Variant = zone_ref.get_ref()
		if is_instance_valid(live_zone) and live_zone is Node:
			(live_zone as Node).queue_free()
	if combat_ctrl_ref != null:
		var live_ctrl: Variant = combat_ctrl_ref.get_ref()
		if is_instance_valid(live_ctrl) and live_ctrl is AICombatController:
			(live_ctrl as AICombatController).is_casting_ability = false
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	notify_components_cast_finished(live_attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Giga-strefa ostrzału z płynnym wygaszaniem i auto-sprzątaniem
# ==============================================================================
class BarrageZoneIndicator extends Node2D:
	const RING_POINTS: int = 72
	const FADE_IN_SEC: float = 0.25
	const FADE_OUT_SEC: float = 0.35
	const PULSE_SPEED_RAD: float = 5.5
	const ROTATE_MARKERS_SPEED_RAD: float = 0.65
	const MARKER_COUNT: int = 8
	const MARKER_ARC_LEN_RAD: float = 0.14
	const OUTER_BORDER_WIDTH_PX: float = 3.2
	const INNER_BORDER_RATIO: float = 0.96
	const INNER_BORDER_WIDTH_PX: float = 1.6

	var _caster_ref: WeakRef = null
	var _radius: float = 300.0
	var _duration: float = 6.0
	var _elapsed: float = 0.0
	var _fill_color: Color = Color(0.8, 0.1, 0.2, 0.2)
	var _outline_color: Color = Color(1.0, 0.1, 0.1, 0.7)
	var _cancel_on_death: bool = true

	func setup(
		caster: Node2D,
		radius: float,
		duration: float,
		fill_color: Color,
		outline_color: Color,
		cancel_on_death: bool,
		z_layer: int
	) -> void:
		_caster_ref = weakref(caster) if is_instance_valid(caster) else null
		_radius = radius
		_duration = duration
		_fill_color = fill_color
		_outline_color = outline_color
		_cancel_on_death = cancel_on_death
		z_as_relative = false
		z_index = z_layer

	func _process(delta: float) -> void:
		if _cancel_on_death:
			var live_caster: Variant = _caster_ref.get_ref() if _caster_ref != null else null
			if not AIAbility.is_caster_active(live_caster):
				queue_free()
				return

		_elapsed += delta
		queue_redraw()
		if _elapsed >= _duration and get_child_count() == 0:
			queue_free()

	func _draw() -> void:
		if _elapsed >= _duration:
			return

		var envelope: float = 1.0
		if _elapsed < FADE_IN_SEC:
			envelope = clampf(_elapsed / FADE_IN_SEC, 0.0, 1.0)
		elif _duration - _elapsed < FADE_OUT_SEC:
			envelope = clampf((_duration - _elapsed) / FADE_OUT_SEC, 0.0, 1.0)

		var fill_col := Color(_fill_color.r, _fill_color.g, _fill_color.b, _fill_color.a * envelope)
		draw_circle(Vector2.ZERO, _radius, fill_col)

		var pulse: float = (sin(_elapsed * PULSE_SPEED_RAD) + 1.0) * 0.5
		var ring_alpha: float = lerpf(0.35, 0.85, pulse) * envelope
		var main_outline := Color(_outline_color.r, _outline_color.g, _outline_color.b, ring_alpha)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, RING_POINTS, main_outline, OUTER_BORDER_WIDTH_PX, true)

		var inner_outline := Color(_outline_color.r, _outline_color.g, _outline_color.b, ring_alpha * 0.5)
		draw_arc(Vector2.ZERO, _radius * INNER_BORDER_RATIO, 0.0, TAU, RING_POINTS, inner_outline, INNER_BORDER_WIDTH_PX, true)

		# Wirujące znaczniki kierunkowe po obwodzie wielkiej strefy
		var marker_col: Color = _outline_color.lightened(0.35)
		marker_col.a = 0.85 * envelope
		var spin: float = _elapsed * ROTATE_MARKERS_SPEED_RAD
		for i in range(MARKER_COUNT):
			var start_a: float = ((float(i) / float(MARKER_COUNT)) * TAU) + spin
			draw_arc(Vector2.ZERO, _radius, start_a, start_a + MARKER_ARC_LEN_RAD, 8, marker_col, OUTER_BORDER_WIDTH_PX * 1.4, true)
