extends AIAbility
class_name DashStrikeAbility
## Uniwersalny archetyp telegrafowanego doskoku z uderzeniem w szczycie ruchu i opcjonalnym powrotem (SOLID - SRP / OCP / DRY).
## Przed doskokiem wyświetla wyraźny korytarz ostrzegawczy ze strzałką, dając graczowi okno na unik,
## a po starcie rysuje smugę ruchu. Zachowania specjalne (np. StealItemAbilityComponent) podpina się w .tres!

#region Stałe Domenowe (Brak magicznych liczb)
const HALF_CAST_TIME_FACTOR: float = 0.5
const DEFAULT_DASH_MAX_RANGE: float = 110.0
const IMPACT_SPARK_COUNT: int = 8
const IMPACT_SPARK_RADIUS_PX: float = 26.0
const DASH_STREAK_DURATION_SEC: float = 0.24
const CASTER_TELEGRAPH_TINT_WEIGHT: float = 0.55
#endregion

@export_category("Archetyp: Telegrafowany Doskok z Uderzeniem (DashStrikeAbility)")

@export_group("Telegrafowanie i Unik (UX)")
## Czas ostrzegania przed doskokiem, podczas którego widać korytarz ze strzałką kierunku (0.0 wyłącza telegraf).
@export_range(0.0, 2.0, 0.05) var telegraph_time: float = 0.45
## Czy podczas telegrafowania kierunek doskoku podąża za celem? False (domyślnie) pozwala graczowi czysto uniknąć ciosu w bok!
@export var track_target_during_telegraph: bool = false
## Kolor korytarza ostrzegawczego, smugi doskoku oraz rozbłysku impaktu (np. bursztyn/złoto dla kradzieży).
@export var telegraph_color: Color = Color(1.0, 0.78, 0.14, 0.85)
## Szerokość wizualnego korytarza ostrzegawczego (w pikselach).
@export_range(16.0, 120.0, 2.0) var telegraph_width_px: float = 34.0
## Warstwa renderowania (Z-Index) korytarza ostrzegawczego i smugi doskoku.
@export var telegraph_z_index: int = GameLayers.HAZARD

@export_group("Parametry Doskoku i Trafienia")
## Całkowity czas trwania ruchu doskoku (w obie strony, jeśli włączono return_to_start_position).
@export_range(0.1, 2.0, 0.05) var cast_time: float = 0.30
## Maksymalny dystans (w pikselach), na jaki rzucający doskakuje w kierunku celu.
@export_range(10.0, 400.0, 10.0) var dash_distance: float = 120.0
## Zasięg samego ciosu/chwytu w szczycie doskoku (od krawędzi do krawędzi — wyjście poza ten dystans daje udany unik!).
@export_range(15.0, 250.0, 5.0) var strike_reach: float = 55.0
## Czy po wykonaniu uderzenia rzucający ma natychmiast odskoczyć na pozycję startową?
@export var return_to_start_position: bool = true

func _init() -> void:
	ability_name = "Doskok z Uderzeniem"
	cooldown = 12.0
	min_range = 0.0
	max_range = DEFAULT_DASH_MAX_RANGE
	damage_category = Effect.EffectCategory.PHYSICAL_DAMAGE

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var attacker_ref: WeakRef = weakref(attacker)
	var target_ref: WeakRef = weakref(target)
	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	var combat_ctrl_ref: WeakRef = weakref(combat_ctrl) if combat_ctrl != null else null
	notify_components_cast_started(attacker, target)

	var sprite: CanvasItem = attacker.get_visual_sprite()
	var sprite_ref: WeakRef = weakref(sprite) if sprite != null else null
	var orig_modulate: Color = sprite.self_modulate if sprite != null else Color.WHITE

	var scene_tree: SceneTree = attacker.get_tree()
	if scene_tree == null:
		_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate, null)
		return

	# 1. Wyznaczenie początkowej trasy doskoku
	var dash_plan: Dictionary = _compute_dash_plan(attacker, target)
	var aim_direction: Vector2 = dash_plan["direction"]
	var forward_pos: Vector2 = dash_plan["end_pos"]
	orient_towards(attacker, aim_direction)

	# =========================================================
	# FAZA 1: TELEGRAFOWANIE (KORYTARZ ZE STRZAŁKĄ — OKNO NA UNIK)
	# =========================================================
	var telegraph_ref: WeakRef = null
	if telegraph_time > 0.0:
		var telegraph_vis := DashTelegraphVisual.new()
		telegraph_vis.setup(
			attacker,
			attacker.global_position,
			forward_pos,
			telegraph_width_px,
			strike_reach,
			telegraph_color,
			telegraph_time,
			telegraph_z_index
		)
		telegraph_ref = weakref(telegraph_vis)
		spawn_ability_node(attacker, telegraph_vis, attacker.global_position)

		if is_instance_valid(sprite) and not attacker.is_frozen:
			var tint_tween: Tween = attacker.create_tracked_tween()
			tint_tween.tween_property(
				sprite,
				"self_modulate",
				orig_modulate.lerp(telegraph_color, CASTER_TELEGRAPH_TINT_WEIGHT),
				telegraph_time
			).set_trans(Tween.TRANS_SINE)

		var elapsed: float = 0.0
		while elapsed < telegraph_time:
			var live_caster: Variant = attacker_ref.get_ref()
			if not is_caster_active(live_caster):
				_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate, telegraph_ref)
				return

			var caster: CharacterEntity = live_caster as CharacterEntity
			if track_target_during_telegraph:
				var live_tgt: Variant = target_ref.get_ref()
				if is_instance_valid(live_tgt) and live_tgt is Node2D:
					dash_plan = _compute_dash_plan(caster, live_tgt as Node2D)
					aim_direction = dash_plan["direction"]
					forward_pos = dash_plan["end_pos"]
					orient_towards(caster, aim_direction)

			var live_tele: Variant = telegraph_ref.get_ref()
			if is_instance_valid(live_tele) and live_tele is DashTelegraphVisual:
				(live_tele as DashTelegraphVisual).update_geometry(caster.global_position, forward_pos)

			elapsed += caster.get_physics_process_delta_time()
			await scene_tree.physics_frame

		_restore_sprite_modulate(attacker_ref, sprite_ref, orig_modulate)
		_free_weak_node(telegraph_ref)
		telegraph_ref = null

	if not is_caster_active(attacker_ref.get_ref()):
		_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate, null)
		return

	# =========================================================
	# FAZA 2: SZYBKI KINEMATYCZNY DOSKOK I SMUGA RUCHU
	# =========================================================
	var live_attacker: CharacterEntity = attacker_ref.get_ref() as CharacterEntity
	var original_pos: Vector2 = live_attacker.global_position
	var dash_in_duration: float = cast_time * HALF_CAST_TIME_FACTOR if return_to_start_position else cast_time

	var streak := DashStreakVisual.new()
	streak.setup(original_pos, forward_pos, telegraph_width_px * 0.65, telegraph_color, DASH_STREAK_DURATION_SEC, GameLayers.FX)
	spawn_ability_node(live_attacker, streak, original_pos)

	var dash_in_tween: Tween = create_kinematic_dash_tween(
		live_attacker,
		forward_pos,
		dash_in_duration,
		Tween.TRANS_EXPO,
		Tween.EASE_OUT
	)

	await dash_in_tween.finished
	if not is_caster_active(attacker_ref.get_ref()):
		_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate, null)
		return

	# =========================================================
	# FAZA 3: SPRAWDZENIE TRAFIENIA W SZCZYCIE DOSKOKU
	# =========================================================
	live_attacker = attacker_ref.get_ref() as CharacterEntity
	var live_target: Variant = target_ref.get_ref()
	if is_instance_valid(live_target) and live_target is CharacterEntity:
		var tgt: CharacterEntity = live_target as CharacterEntity
		if not tgt.is_dead and not tgt.is_respawning:
			var post_dash_edge_dist: float = get_edge_distance(live_attacker, tgt)
			if post_dash_edge_dist <= strike_reach and can_affect_target(live_attacker, tgt, false, true, false):
				live_attacker.play_unarmed_attack_animation(tgt.global_position)
				var hit_effects: Array[Effect] = build_hit_effects(live_attacker)
				apply_effects_to_target(live_attacker, tgt, hit_effects, live_attacker.global_position)
				notify_components_area_detonated(live_attacker, tgt.global_position, strike_reach)
				notify_components_target_hit(live_attacker, tgt, live_attacker.global_position)
				CombatVFXHelper.spawn_impact_sparks(
					live_attacker,
					tgt.global_position,
					aim_direction,
					telegraph_color,
					IMPACT_SPARK_COUNT,
					IMPACT_SPARK_RADIUS_PX
				)

	# =========================================================
	# FAZA 4: OPCJONALNY POWRÓT NA POZYCJĘ STARTOWĄ
	# =========================================================
	if return_to_start_position and is_caster_active(attacker_ref.get_ref()):
		var dash_back_tween: Tween = create_kinematic_dash_tween(
			attacker_ref.get_ref() as CharacterEntity,
			original_pos,
			dash_in_duration,
			Tween.TRANS_SINE,
			Tween.EASE_IN
		)
		await dash_back_tween.finished

	_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate, null)

## Oblicza wektor kierunku oraz bezpieczny punkt końcowy doskoku przed przeszkodami.
func _compute_dash_plan(attacker: CharacterEntity, target: Node2D) -> Dictionary:
	var original_pos: Vector2 = attacker.global_position
	var aim_dir: Vector2 = original_pos.direction_to(target.global_position)
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	var edge_distance: float = get_edge_distance(attacker, target)
	var actual_dash_distance: float = minf(dash_distance, edge_distance)
	var move_vec: Vector2 = aim_dir * actual_dash_distance

	var col: KinematicCollision2D = attacker.move_and_collide(move_vec, true)
	var end_pos: Vector2 = original_pos + (col.get_travel() if col != null else move_vec)
	return {"direction": aim_dir, "end_pos": end_pos}

func _restore_sprite_modulate(attacker_ref: WeakRef, sprite_ref: WeakRef, orig_modulate: Color) -> void:
	if sprite_ref == null:
		return
	var live_sprite: Variant = sprite_ref.get_ref()
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	if is_instance_valid(live_sprite) and live_sprite is CanvasItem:
		if not (is_caster_active(live_attacker) and (live_attacker as CharacterEntity).is_frozen):
			(live_sprite as CanvasItem).self_modulate = orig_modulate

func _free_weak_node(node_ref: WeakRef) -> void:
	if node_ref == null:
		return
	var live_node: Variant = node_ref.get_ref()
	if is_instance_valid(live_node) and live_node is Node:
		(live_node as Node).queue_free()

## Bezpiecznie kończy rzucanie zdolności (WeakRef gwarantuje brak błędów po śmierci rzucającego w trakcie await).
func _finish_cast(
	attacker_ref: WeakRef,
	combat_ctrl_ref: WeakRef,
	sprite_ref: WeakRef,
	orig_modulate: Color,
	telegraph_ref: WeakRef
) -> void:
	_restore_sprite_modulate(attacker_ref, sprite_ref, orig_modulate)
	_free_weak_node(telegraph_ref)
	if combat_ctrl_ref != null:
		var live_ctrl: Variant = combat_ctrl_ref.get_ref()
		if is_instance_valid(live_ctrl) and live_ctrl is AICombatController:
			(live_ctrl as AICombatController).is_casting_ability = false
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	notify_components_cast_finished(live_attacker)

# ==============================================================================
# KLASY WEWNĘTRZNE: Korytarz ostrzegawczy (Telegraf) oraz smuga doskoku
# ==============================================================================
class DashTelegraphVisual extends Node2D:
	const MIN_DURATION_SEC: float = 0.05
	const FAILSAFE_EXTRA_SEC: float = 0.15
	const BG_ALPHA: float = 0.20
	const FILL_ALPHA: float = 0.45
	const BORDER_WIDTH_PX: float = 2.2
	const CHEVRON_COUNT: int = 3
	const CHEVRON_SPREAD_RAD: float = 2.45
	const END_RING_POINTS: int = 32
	const MIN_PATH_LEN_PX: float = 4.0

	var _caster_ref: WeakRef = null
	var _start_pos: Vector2 = Vector2.ZERO
	var _end_pos: Vector2 = Vector2.ZERO
	var _width: float = 34.0
	var _strike_radius: float = 55.0
	var _color: Color = Color.GOLD
	var _duration: float = 0.45
	var _elapsed: float = 0.0

	func setup(
		caster: Node2D,
		start_pos: Vector2,
		end_pos: Vector2,
		width: float,
		strike_radius: float,
		color: Color,
		duration: float,
		z_layer: int
	) -> void:
		_caster_ref = weakref(caster) if is_instance_valid(caster) else null
		_start_pos = start_pos
		_end_pos = end_pos
		_width = width
		_strike_radius = strike_radius
		_color = color
		_duration = maxf(MIN_DURATION_SEC, duration)
		top_level = true
		z_as_relative = false
		z_index = z_layer

	func update_geometry(new_start: Vector2, new_end: Vector2) -> void:
		_start_pos = new_start
		_end_pos = new_end
		global_position = _start_pos

	func _process(delta: float) -> void:
		var live_caster: Variant = _caster_ref.get_ref() if _caster_ref != null else null
		if not AIAbility.is_caster_active(live_caster):
			queue_free()
			return
		_elapsed += delta
		if _elapsed >= _duration + FAILSAFE_EXTRA_SEC:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
		var local_end: Vector2 = _end_pos - _start_pos
		var path_len: float = local_end.length()
		var dir: Vector2 = local_end.normalized() if path_len > MIN_PATH_LEN_PX else Vector2.RIGHT
		var perp: Vector2 = dir.orthogonal() * (_width * 0.5)

		# 1. Korytarz doskoku (tło + rosnące wypełnienie + krawędzie)
		if path_len > MIN_PATH_LEN_PX:
			var bg_poly := PackedVector2Array([perp, -perp, local_end - perp, local_end + perp])
			draw_colored_polygon(bg_poly, Color(_color.r, _color.g, _color.b, BG_ALPHA))

			var fill_end: Vector2 = local_end * progress
			var fill_poly := PackedVector2Array([perp, -perp, fill_end - perp, fill_end + perp])
			draw_colored_polygon(fill_poly, Color(_color.r, _color.g, _color.b, FILL_ALPHA))

			var border_col := Color(_color.r, _color.g, _color.b, lerpf(0.65, 1.0, progress))
			draw_line(perp, local_end + perp, border_col, BORDER_WIDTH_PX, true)
			draw_line(-perp, local_end - perp, border_col, BORDER_WIDTH_PX, true)

			# Strzałki kierunkowe płynące w stronę celu
			var chevron_len: float = _width * 0.42
			var wing_left: Vector2 = dir.rotated(CHEVRON_SPREAD_RAD) * chevron_len
			var wing_right: Vector2 = dir.rotated(-CHEVRON_SPREAD_RAD) * chevron_len
			var chevron_col: Color = _color.lightened(0.45)
			chevron_col.a = lerpf(0.55, 0.98, progress)
			for i in range(CHEVRON_COUNT):
				var frac: float = fmod((float(i) / float(CHEVRON_COUNT)) + progress, 1.0)
				var tip: Vector2 = local_end * frac
				draw_line(tip + wing_left, tip, chevron_col, BORDER_WIDTH_PX, true)
				draw_line(tip + wing_right, tip, chevron_col, BORDER_WIDTH_PX, true)

		# 2. Okrąg zasięgu chwytu/uderzenia w punkcie docelowym
		var ring_col := Color(_color.r, _color.g, _color.b, lerpf(0.45, 0.95, progress))
		draw_circle(local_end, _strike_radius * progress, Color(_color.r, _color.g, _color.b, BG_ALPHA))
		draw_arc(local_end, _strike_radius, 0.0, TAU, END_RING_POINTS, ring_col, BORDER_WIDTH_PX, true)

class DashStreakVisual extends Node2D:
	const MIN_DURATION_SEC: float = 0.05
	const CORE_WIDTH_RATIO: float = 0.35

	var _start_pos: Vector2 = Vector2.ZERO
	var _end_pos: Vector2 = Vector2.ZERO
	var _width: float = 20.0
	var _color: Color = Color.GOLD
	var _duration: float = 0.24
	var _elapsed: float = 0.0

	func setup(start_pos: Vector2, end_pos: Vector2, width: float, color: Color, duration: float, z_layer: int) -> void:
		_start_pos = start_pos
		_end_pos = end_pos
		_width = width
		_color = color
		_duration = maxf(MIN_DURATION_SEC, duration)
		top_level = true
		z_as_relative = false
		z_index = z_layer

	func _ready() -> void:
		global_position = _start_pos

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= _duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade: float = 1.0 - clampf(_elapsed / _duration, 0.0, 1.0)
		var local_end: Vector2 = _end_pos - _start_pos
		var outer_col := Color(_color.r, _color.g, _color.b, 0.65 * fade)
		var core_col: Color = _color.lightened(0.60)
		core_col.a = 0.90 * fade
		draw_line(Vector2.ZERO, local_end, outer_col, _width * fade, true)
		draw_line(Vector2.ZERO, local_end, core_col, _width * CORE_WIDTH_RATIO * fade, true)
