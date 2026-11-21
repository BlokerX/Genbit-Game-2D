class_name CombatVFXHelper
extends RefCounted
## Centralny serwis lekkich, proceduralnych efektów wizualnych walki (SOLID - SRP / DRY).
## Generuje samooczyszczające się fale uderzeniowe, rozbłyski iskier, kroplowe smugi pocisków/noży
## oraz wielowarstwowe eksplozje bez duplikowania logiki _draw() między skryptami.

#region Stałe Konfiguracyjne VFX (Brak magicznych liczb)
const DEFAULT_SHOCKWAVE_DURATION_SEC: float = 0.28
const DEFAULT_SHOCKWAVE_FILL_ALPHA: float = 0.22
const DEFAULT_SPARK_COUNT: int = 7
const DEFAULT_SPARK_RADIUS_PX: float = 20.0
const DEFAULT_SPARK_DURATION_SEC: float = 0.20
const DEFAULT_EXPLOSION_DURATION_SEC: float = 0.36
const DEFAULT_EXPLOSION_CORE_COLOR := Color(1.0, 0.96, 0.78, 1.0)

## Parametry geometryczne i kolorystyczne smugi kroplowej (droplet envelope).
const DROPLET_ARC_SEGMENTS: int = 10
const DROPLET_MIN_CONVEX_MARGIN_PX: float = 2.0
const DROPLET_OUTER_ALPHA: float = 0.40
const DROPLET_INNER_ALPHA: float = 0.68
const DROPLET_INNER_WIDTH_RATIO: float = 0.62
const DROPLET_INNER_HEAD_RATIO: float = 0.78
const DROPLET_INNER_TAIL_RATIO: float = 0.72
const DROPLET_INNER_LIGHTEN: float = 0.28
const DROPLET_GLINT_ALPHA: float = 0.72
const DROPLET_GLINT_RADIUS_RATIO: float = 0.36
const DROPLET_GLINT_HEAD_RATIO: float = 0.68
const DROPLET_GLINT_LIGHTEN: float = 0.60

const PRIORITY_ELEMENTAL: int = 3
const PRIORITY_CUSTOM_COLOR: int = 2
const PRIORITY_MOVEMENT_CC: int = 2
const PRIORITY_GENERIC_CC: int = 1

## Mapa kolorów VFX przypisanych do kategorii żywiołów i statusów (SOLID - OCP, brak drabin if/elif).
const ELEMENTAL_CATEGORY_COLORS: Dictionary = {
	Effect.EffectCategory.FROST_FREEZE: Color(0.35, 0.85, 1.0, 0.95),
	Effect.EffectCategory.POISON_ACID: Color(0.28, 0.95, 0.22, 0.95),
	Effect.EffectCategory.FIRE_BURN: Color(1.0, 0.45, 0.12, 0.95),
	Effect.EffectCategory.RADIATION: Color(0.55, 1.0, 0.18, 0.95),
	Effect.EffectCategory.MENTAL_PSYCHOSIS: Color(0.72, 0.30, 1.0, 0.95),
	Effect.EffectCategory.HEAL: Color(0.32, 0.98, 0.52, 0.95),
	Effect.EffectCategory.SLOW: Color(0.55, 0.72, 0.95, 0.95),
	Effect.EffectCategory.STUN: Color(1.0, 0.92, 0.30, 0.95)
}

## Priorytety kategorii przy doborze koloru VFX: żywioły zawsze wygrywają nad ogólnym StunEffect broni!
const ELEMENTAL_CATEGORY_PRIORITIES: Dictionary = {
	Effect.EffectCategory.FROST_FREEZE: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.POISON_ACID: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.FIRE_BURN: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.RADIATION: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.MENTAL_PSYCHOSIS: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.HEAL: PRIORITY_ELEMENTAL,
	Effect.EffectCategory.SLOW: PRIORITY_MOVEMENT_CC,
	Effect.EffectCategory.STUN: PRIORITY_GENERIC_CC
}
#endregion

## Zwraca true, jeśli tablica efektów zawiera efekt żywiołowy/specjalny (inny niż zwykłe obrażenia fizyczne i samo ogłuszenie).
static func has_elemental_effect(effects: Array[Effect]) -> bool:
	for eff in effects:
		if eff == null:
			continue
		var cat: Effect.EffectCategory = eff.get_effective_category()
		if int(ELEMENTAL_CATEGORY_PRIORITIES.get(cat, 0)) >= PRIORITY_MOVEMENT_CC:
			return true
		if cat == Effect.EffectCategory.NONE and eff.effect_color.a > 0.0 and not eff.effect_color.is_equal_approx(Color.WHITE):
			return true
	return false

## Dobiera dominujący kolor VFX na podstawie priorytetów kategorii w liście efektów (DRY / OCP).
## Żywioły (np. FROST_FREEZE, POISON_ACID, FIRE_BURN) zawsze mają pierwszeństwo przed ogólnym STUN.
static func resolve_color_from_effects(effects: Array[Effect], default_color: Color) -> Color:
	if effects.is_empty():
		return default_color

	var best_priority: int = 0
	var best_color: Color = default_color

	for eff in effects:
		if eff == null:
			continue
		var cat: Effect.EffectCategory = eff.get_effective_category()
		if ELEMENTAL_CATEGORY_COLORS.has(cat):
			var priority: int = int(ELEMENTAL_CATEGORY_PRIORITIES.get(cat, PRIORITY_GENERIC_CC))
			if priority > best_priority:
				best_priority = priority
				best_color = ELEMENTAL_CATEGORY_COLORS[cat]
		elif cat == Effect.EffectCategory.NONE:
			var custom_col: Color = eff.effect_color
			if custom_col.a > 0.0 and not custom_col.is_equal_approx(Color.WHITE):
				if PRIORITY_CUSTOM_COLOR > best_priority:
					best_priority = PRIORITY_CUSTOM_COLOR
					best_color = custom_col

	return best_color

## Rysuje płynną, dwuwarstwową kroplę / otoczkę smugi wysuniętą lekko przed czubek pocisku lub noża (DRY).
## Geometria kropli jest matematycznie wypukła, więc draw_colored_polygon zawsze renderuje ją bez artefaktów.
static func draw_droplet_trail(
	canvas: CanvasItem,
	world_direction: Vector2,
	world_rotation: float,
	head_lead_px: float,
	tail_length_px: float,
	width_px: float,
	color: Color
) -> void:
	if canvas == null or world_direction == Vector2.ZERO or width_px <= 0.5:
		return

	var fwd: Vector2 = world_direction.normalized().rotated(-world_rotation)
	var perp: Vector2 = fwd.orthogonal()
	var outer_radius: float = maxf(1.0, width_px * 0.5)

	# 1. Zewnętrzna, półprzezroczysta kropla otaczająca cały pocisk / nóż
	var outer_poly: PackedVector2Array = _build_teardrop_polygon(fwd, perp, head_lead_px, tail_length_px, outer_radius)
	var outer_col := Color(color.r, color.g, color.b, DROPLET_OUTER_ALPHA)
	canvas.draw_colored_polygon(outer_poly, outer_col)

	# 2. Wewnętrzny, jaśniejszy rdzeń kropli
	var inner_radius: float = maxf(0.8, outer_radius * DROPLET_INNER_WIDTH_RATIO)
	var inner_poly: PackedVector2Array = _build_teardrop_polygon(
		fwd,
		perp,
		head_lead_px * DROPLET_INNER_HEAD_RATIO,
		tail_length_px * DROPLET_INNER_TAIL_RATIO,
		inner_radius
	)
	var inner_col: Color = color.lightened(DROPLET_INNER_LIGHTEN)
	inner_col.a = DROPLET_INNER_ALPHA
	canvas.draw_colored_polygon(inner_poly, inner_col)

	# 3. Delikatny rozbłysk na przedniej krawędzi kropli
	var glint_col: Color = color.lightened(DROPLET_GLINT_LIGHTEN)
	glint_col.a = DROPLET_GLINT_ALPHA
	canvas.draw_circle(fwd * (head_lead_px * DROPLET_GLINT_HEAD_RATIO), outer_radius * DROPLET_GLINT_RADIUS_RATIO, glint_col)

## Buduje wypukły wielokąt kropli: półkole z przodu na wysokości head_lead_px zwężające się do punktu tail_length_px z tyłu.
static func _build_teardrop_polygon(
	fwd: Vector2,
	perp: Vector2,
	head_lead_px: float,
	tail_length_px: float,
	radius: float
) -> PackedVector2Array:
	var nose_center: Vector2 = fwd * head_lead_px
	# Gwarancja ścisłej wypukłości wielokąta (ogon zawsze znajduje się za tylną krawędzią półkola nosa)
	var safe_tail_dist: float = maxf(tail_length_px, radius - head_lead_px + DROPLET_MIN_CONVEX_MARGIN_PX)
	var tail_tip: Vector2 = -fwd * safe_tail_dist

	var poly := PackedVector2Array()
	poly.resize(DROPLET_ARC_SEGMENTS + 2)
	for i in range(DROPLET_ARC_SEGMENTS + 1):
		var angle: float = lerpf(-PI * 0.5, PI * 0.5, float(i) / float(DROPLET_ARC_SEGMENTS))
		var arc_offset: Vector2 = ((fwd * cos(angle)) + (perp * sin(angle))) * radius
		poly[i] = nose_center + arc_offset
	poly[DROPLET_ARC_SEGMENTS + 1] = tail_tip
	return poly

## Spawnuje rozchodzącą się falę uderzeniową (podwójny pierścień + opcjonalne miękkie wypełnienie).
static func spawn_shockwave(
	context_node: Node,
	world_pos: Vector2,
	radius: float,
	color: Color,
	duration: float = DEFAULT_SHOCKWAVE_DURATION_SEC,
	z_layer: int = GameLayers.FX,
	fill_alpha: float = DEFAULT_SHOCKWAVE_FILL_ALPHA
) -> void:
	if not is_instance_valid(context_node) or not context_node.is_inside_tree() or radius <= 0.0:
		return
	var vfx := _ShockwaveRingVFX.new()
	vfx.setup(world_pos, radius, color, duration, z_layer, fill_alpha)
	_attach_vfx_to_world(context_node, vfx)

## Spawnuje krótki rozbłysk iskier kierunkowych w miejscu uderzenia pocisku, lasera lub ciosu.
static func spawn_impact_sparks(
	context_node: Node,
	world_pos: Vector2,
	direction_hint: Vector2,
	color: Color,
	spark_count: int = DEFAULT_SPARK_COUNT,
	radius: float = DEFAULT_SPARK_RADIUS_PX,
	duration: float = DEFAULT_SPARK_DURATION_SEC,
	z_layer: int = GameLayers.FX
) -> void:
	if not is_instance_valid(context_node) or not context_node.is_inside_tree() or spark_count <= 0:
		return
	var vfx := _ImpactSparksVFX.new()
	vfx.setup(world_pos, direction_hint, color, spark_count, radius, duration, z_layer)
	_attach_vfx_to_world(context_node, vfx)

## Spawnuje wielowarstwowy wybuch (jasny rdzeń + fala uderzeniowa + rozpryskujące się iskry).
static func spawn_explosion(
	context_node: Node,
	world_pos: Vector2,
	radius: float,
	primary_color: Color,
	core_color: Color = DEFAULT_EXPLOSION_CORE_COLOR,
	duration: float = DEFAULT_EXPLOSION_DURATION_SEC,
	z_layer: int = GameLayers.FX
) -> void:
	if not is_instance_valid(context_node) or not context_node.is_inside_tree() or radius <= 0.0:
		return
	var vfx := _ExplosionVFX.new()
	vfx.setup(world_pos, radius, primary_color, core_color, duration, z_layer)
	_attach_vfx_to_world(context_node, vfx)

## Bezpiecznie podpina węzeł VFX do aktywnej Mapy (lub current_scene), aby przeżył zniszczenie pocisku/plamy
## i automatycznie zniknął przy zmianie poziomu lub wyjściu do menu głównego.
static func _attach_vfx_to_world(context_node: Node, vfx: Node2D) -> void:
	var tree: SceneTree = context_node.get_tree()
	if tree == null:
		vfx.queue_free()
		return
	var host_parent: Node = tree.get_first_node_in_group("Map")
	if not is_instance_valid(host_parent):
		host_parent = tree.current_scene
	if not is_instance_valid(host_parent):
		vfx.queue_free()
		return
	host_parent.call_deferred("add_child", vfx)

# ==============================================================================
# KLASY WEWNĘTRZNE VFX (Samooczyszczające się, zero magicznych liczb)
# ==============================================================================

## Rozchodząca się fala uderzeniowa (dwupierścieniowa) używana m.in. przy wybuchu TelegraphedAOE i lądowaniu bossa.
class _ShockwaveRingVFX extends Node2D:
	const RING_POINTS: int = 44
	const MIN_DURATION_SEC: float = 0.05
	const START_RADIUS_RATIO: float = 0.28
	const END_RADIUS_RATIO: float = 1.12
	const INNER_RING_RATIO: float = 0.78
	const START_LINE_WIDTH_PX: float = 6.0
	const END_LINE_WIDTH_PX: float = 1.0
	const INNER_WIDTH_RATIO: float = 0.45
	const CORE_FLASH_LIGHTEN: float = 0.55

	var _spawn_pos: Vector2 = Vector2.ZERO
	var _radius: float = 60.0
	var _color: Color = Color.WHITE
	var _duration: float = 0.28
	var _fill_alpha: float = 0.22
	var _progress: float = 0.0

	func setup(
		world_pos: Vector2,
		radius: float,
		color: Color,
		duration: float,
		z_layer: int,
		fill_alpha: float
	) -> void:
		_spawn_pos = world_pos
		_radius = radius
		_color = color
		_duration = maxf(MIN_DURATION_SEC, duration)
		_fill_alpha = clampf(fill_alpha, 0.0, 1.0)
		top_level = true
		z_as_relative = false
		z_index = z_layer

	func _ready() -> void:
		global_position = _spawn_pos

	func _process(delta: float) -> void:
		_progress = minf(1.0, _progress + (delta / _duration))
		queue_redraw()
		if _progress >= 1.0:
			queue_free()

	func _draw() -> void:
		var eased: float = 1.0 - pow(1.0 - _progress, 2.0)
		var fade: float = 1.0 - _progress
		var cur_radius: float = _radius * lerpf(START_RADIUS_RATIO, END_RADIUS_RATIO, eased)
		var ring_width: float = lerpf(START_LINE_WIDTH_PX, END_LINE_WIDTH_PX, _progress)

		if _fill_alpha > 0.0:
			var fill_col := Color(_color.r, _color.g, _color.b, _fill_alpha * fade)
			draw_circle(Vector2.ZERO, cur_radius, fill_col)

		var outer_col := Color(_color.r, _color.g, _color.b, clampf(_color.a, 0.5, 1.0) * fade)
		draw_arc(Vector2.ZERO, cur_radius, 0.0, TAU, RING_POINTS, outer_col, ring_width, true)

		var inner_col: Color = _color.lightened(CORE_FLASH_LIGHTEN)
		inner_col.a = fade * 0.85
		draw_arc(
			Vector2.ZERO,
			cur_radius * INNER_RING_RATIO,
			0.0,
			TAU,
			RING_POINTS,
			inner_col,
			ring_width * INNER_WIDTH_RATIO,
			true
		)

## Rozbłysk iskier kierunkowych w punkcie impaktu pocisku, wiązki lub uderzenia.
class _ImpactSparksVFX extends Node2D:
	const MIN_DURATION_SEC: float = 0.05
	const CONE_SPREAD_RAD: float = 1.35
	const FULL_SPREAD_RAD: float = PI
	const SPEED_MIN_MULT: float = 0.55
	const SPEED_MAX_MULT: float = 1.15
	const TAIL_LENGTH_RATIO: float = 0.42
	const CORE_FLASH_RATIO: float = 0.30
	const START_LINE_WIDTH_PX: float = 2.6
	const END_LINE_WIDTH_PX: float = 0.8

	var _spawn_pos: Vector2 = Vector2.ZERO
	var _color: Color = Color.WHITE
	var _radius: float = 20.0
	var _duration: float = 0.20
	var _progress: float = 0.0
	var _spark_angles: PackedFloat32Array = PackedFloat32Array()
	var _spark_lengths: PackedFloat32Array = PackedFloat32Array()

	func setup(
		world_pos: Vector2,
		direction_hint: Vector2,
		color: Color,
		spark_count: int,
		radius: float,
		duration: float,
		z_layer: int
	) -> void:
		_spawn_pos = world_pos
		_color = color
		_radius = radius
		_duration = maxf(MIN_DURATION_SEC, duration)
		top_level = true
		z_as_relative = false
		z_index = z_layer

		var has_dir: bool = direction_hint.length_squared() > 0.001
		var base_angle: float = direction_hint.angle() if has_dir else 0.0
		var spread: float = CONE_SPREAD_RAD if has_dir else FULL_SPREAD_RAD

		_spark_angles.resize(spark_count)
		_spark_lengths.resize(spark_count)
		for i in range(spark_count):
			var offset: float = randf_range(-spread, spread)
			_spark_angles[i] = base_angle + offset
			_spark_lengths[i] = _radius * randf_range(SPEED_MIN_MULT, SPEED_MAX_MULT)

	func _ready() -> void:
		global_position = _spawn_pos

	func _process(delta: float) -> void:
		_progress = minf(1.0, _progress + (delta / _duration))
		queue_redraw()
		if _progress >= 1.0:
			queue_free()

	func _draw() -> void:
		var fade: float = 1.0 - _progress
		var eased: float = 1.0 - pow(1.0 - _progress, 2.0)
		var width: float = lerpf(START_LINE_WIDTH_PX, END_LINE_WIDTH_PX, _progress)

		var core_col := Color(1.0, 1.0, 1.0, fade * 0.9)
		draw_circle(Vector2.ZERO, _radius * CORE_FLASH_RATIO * fade, core_col)

		var spark_col := Color(_color.r, _color.g, _color.b, fade)
		for i in range(_spark_angles.size()):
			var dir := Vector2.from_angle(_spark_angles[i])
			var head_dist: float = _spark_lengths[i] * eased
			var tail_dist: float = maxf(0.0, head_dist - (_spark_lengths[i] * TAIL_LENGTH_RATIO * fade))
			draw_line(dir * tail_dist, dir * head_dist, spark_col, width, true)

## Wielowarstwowy wybuch (rdzeń + ognista kula + fala uderzeniowa + iskry) dla bomb, granatów i min.
class _ExplosionVFX extends Node2D:
	const RING_POINTS: int = 44
	const MIN_DURATION_SEC: float = 0.08
	const SPARK_COUNT: int = 12
	const CORE_START_RATIO: float = 0.35
	const CORE_END_RATIO: float = 0.72
	const BODY_START_RATIO: float = 0.25
	const BODY_END_RATIO: float = 1.0
	const SHOCKWAVE_END_RATIO: float = 1.22
	const SHOCKWAVE_START_WIDTH_PX: float = 7.0
	const SHOCKWAVE_END_WIDTH_PX: float = 1.2
	const SPARK_TAIL_RATIO: float = 0.28
	const SPARK_WIDTH_PX: float = 2.4

	var _spawn_pos: Vector2 = Vector2.ZERO
	var _radius: float = 80.0
	var _primary_color: Color = Color.ORANGE
	var _core_color: Color = Color.WHITE
	var _duration: float = 0.36
	var _progress: float = 0.0
	var _spark_angles: PackedFloat32Array = PackedFloat32Array()
	var _spark_mults: PackedFloat32Array = PackedFloat32Array()

	func setup(
		world_pos: Vector2,
		radius: float,
		primary_color: Color,
		core_color: Color,
		duration: float,
		z_layer: int
	) -> void:
		_spawn_pos = world_pos
		_radius = radius
		_primary_color = primary_color
		_core_color = core_color
		_duration = maxf(MIN_DURATION_SEC, duration)
		top_level = true
		z_as_relative = false
		z_index = z_layer

		_spark_angles.resize(SPARK_COUNT)
		_spark_mults.resize(SPARK_COUNT)
		for i in range(SPARK_COUNT):
			var base_a: float = (float(i) / float(SPARK_COUNT)) * TAU
			_spark_angles[i] = base_a + randf_range(-0.18, 0.18)
			_spark_mults[i] = randf_range(0.75, 1.20)

	func _ready() -> void:
		global_position = _spawn_pos

	func _process(delta: float) -> void:
		_progress = minf(1.0, _progress + (delta / _duration))
		queue_redraw()
		if _progress >= 1.0:
			queue_free()

	func _draw() -> void:
		var eased: float = 1.0 - pow(1.0 - _progress, 3.0)
		var fade: float = 1.0 - _progress

		# 1. Wypełnienie głównej kuli eksplozji
		var body_radius: float = _radius * lerpf(BODY_START_RATIO, BODY_END_RATIO, eased)
		var body_col := Color(_primary_color.r, _primary_color.g, _primary_color.b, 0.42 * fade)
		draw_circle(Vector2.ZERO, body_radius, body_col)

		# 2. Gorący jasny rdzeń zanikający szybciej niż zewnętrzna chmura
		var core_fade: float = maxf(0.0, 1.0 - (_progress * 1.45))
		if core_fade > 0.0:
			var core_radius: float = _radius * lerpf(CORE_START_RATIO, CORE_END_RATIO, eased)
			var core_col := Color(_core_color.r, _core_color.g, _core_color.b, 0.85 * core_fade)
			draw_circle(Vector2.ZERO, core_radius, core_col)

		# 3. Zewnętrzna fala uderzeniowa
		var wave_radius: float = _radius * lerpf(BODY_START_RATIO, SHOCKWAVE_END_RATIO, eased)
		var wave_width: float = lerpf(SHOCKWAVE_START_WIDTH_PX, SHOCKWAVE_END_WIDTH_PX, _progress)
		var wave_col := Color(_primary_color.r, _primary_color.g, _primary_color.b, 0.92 * fade)
		draw_arc(Vector2.ZERO, wave_radius, 0.0, TAU, RING_POINTS, wave_col, wave_width, true)

		# 4. Promieniste iskry wybuchu
		var spark_col := Color(_core_color.r, _core_color.g, _core_color.b, fade)
		for i in range(_spark_angles.size()):
			var dir := Vector2.from_angle(_spark_angles[i])
			var max_len: float = _radius * _spark_mults[i]
			var head: float = max_len * eased
			var tail: float = maxf(0.0, head - (max_len * SPARK_TAIL_RATIO * fade))
			draw_line(dir * tail, dir * head, spark_col, SPARK_WIDTH_PX * fade, true)
