extends AIAbility
class_name BeamAbility
## Uniwersalny archetyp wiązki energetycznej (SOLID - SRP / OCP / DRY).
## Pozwala tworzyć w plikach .tres dowolne warianty wiązek (np. laser ogniowy, mroźny promień,
## strzał snajperski, wiązka czyszcząca efekty lub wiązka lecząca sojuszników) za pomocą AttackData,
## on_hit_effects oraz modularnych komponentów AbilityComponent (np. CameraShakeAbilityComponent).

## Określa, na kogo oddziałuje wiązka w momencie trafienia.
enum BeamTargetMode {
	ENEMIES_ONLY, ## Oddziałuje wyłącznie na wrogów.
	ALLIES_ONLY,  ## Oddziałuje wyłącznie na sojuszników (np. wiązka lecząca lub wzmacniająca).
	EVERYONE      ## Oddziałuje na wszystkie postacie na linii wiązki (friendly fire).
}

#region Stałe Domenowe i Fizyczne (Brak magicznych liczb)
const CHARGE_PULSE_SPEED_RAD: float = 25.0
const MAX_BEAM_HITS: int = 64
const MIN_DURATION_SEC: float = 0.01
const MIN_BEAM_LENGTH_PX: float = 1.0
const IMPACT_SPARK_INTERVAL_SEC: float = 0.09
const IMPACT_SPARK_COUNT: int = 5
const IMPACT_SPARK_RADIUS_MULT: float = 1.65
const DEFAULT_BEAM_DAMAGE_PER_TICK: int = 5
const DEFAULT_BEAM_MAX_RANGE: float = 800.0
#endregion

@export_group("Oprawa Dźwiękowa Wiązki")
## Dźwięk narastającego ładowania promienia.
@export var charge_feedback_cue: FeedbackCue = preload(
	"res://assets/data/feedback/enemies/laser_charge.tres"
)
## Dźwięk wystrzału po zakończeniu celowania.
@export var fire_feedback_cue: FeedbackCue = preload(
	"res://assets/data/feedback/enemies/laser_fire.tres"
)

@export_category("Archetyp: Wiązka Energetyczna (BeamAbility)")

@export_group("Celowanie, Zasięg i Przeszkody")
## Czas ładowania i celowania przed odpaleniem pełnej wiązki (w sekundach).
@export_range(0.1, 5.0, 0.1) var cast_time: float = 1.5
## Maksymalna długość promienia (w pikselach).
@export_range(50.0, 4000.0, 25.0) var beam_range: float = 2000.0
## Jeśli zaznaczone, promień celownika podąża za celem w trakcie ładowania ataku.
@export var track_target_during_cast: bool = true
## Prędkość obrotu celownika za celem podczas ładowania (0.01 = wolny, 1.0 = natychmiastowy).
@export_range(0.01, 1.0, 0.02) var tracking_smoothness: float = 0.05
## Czy wiązka ma podążać za celem również w trakcie strzelania?
@export var track_target_during_fire: bool = true
## Prędkość obrotu wiązki w trakcie strzału (wolniejsza pozwala graczowi uciec w bok).
@export_range(0.005, 0.5, 0.005) var firing_tracking_smoothness: float = 0.01
## Jeśli włączone, wiązka przenika przez ściany i przeszkody na całej długości beam_range.
@export var pierce_obstacles: bool = false
## Maska fizyki dla ścian/przeszkód zatrzymujących wiązkę (gdy pierce_obstacles == false).
@export_flags_2d_physics var obstacles_mask: int = 1

@export_group("Rytm Strzału i Dobór Celów")
## Czas trwania aktywnego strzału wiązką (w sekundach). Ustaw np. 0.12 dla pojedynczego impulsu snajperskiego.
@export_range(0.05, 10.0, 0.05) var beam_duration: float = 2.3
## Odstęp (w sekundach) pomiędzy kolejnymi aplikacjami efektów (AttackData + on_hit_effects) dla celów stojących w wiązce.
@export_range(0.05, 2.0, 0.05) var damage_tick_rate: float = 0.1
## Określa, które jednostki są obejmowane działaniem wiązki (wrogowie, sojusznicy lub wszyscy).
@export var target_mode: BeamTargetMode = BeamTargetMode.EVERYONE

@export_group("Wizualizacje i VFX Wiązki")
## Szerokość głównego strumienia wiązki oraz jej fizycznego hitboxa (w pikselach).
@export_range(4.0, 120.0, 1.0) var beam_width: float = 15.0
## Główny kolor wiązki i poświaty (np. czerwień ognia, błękit mrozu, zieleń kwasu lub złoto leczenia).
@export var beam_color: Color = Color(1.0, 0.12, 0.10, 1.0)
## Kolor gorącego rdzenia wiązki i rozbłysku w punkcie emisji.
@export var core_color: Color = Color(1.0, 0.96, 0.92, 1.0)
## Czas płynnego wygaszania wiązki po zakończeniu fazy strzału (w sekundach).
@export_range(0.05, 1.0, 0.02) var beam_fade_out_time: float = 0.18
## Warstwa renderowania (Z-Index) dla promienia. Domyślnie GameLayers.FX (nad postaciami).
@export var beam_z_index: int = GameLayers.FX
## Czy podczas ładowania wyświetlać zbierające się pierścienie energii u źródła?
@export var show_charge_rings: bool = true
## Czy generować iskry impaktu w miejscu uderzenia wiązki w ścianę lub cel?
@export var show_impact_sparks: bool = true
## Czy podczas ładowania postać rzucającego ma pulsować kolorem wiązki?
@export var pulse_caster_during_cast: bool = true

func _init() -> void:
	ability_name = "Wiązka Energetyczna"
	cooldown = 12.0
	min_range = 0.0
	max_range = DEFAULT_BEAM_MAX_RANGE
	damage_category = Effect.EffectCategory.FIRE_BURN
	apply_attack_stun = false
	if attack_data == null:
		attack_data = AttackData.new(DEFAULT_BEAM_DAMAGE_PER_TICK, 0, 0.0, DEFAULT_BEAM_MAX_RANGE, 0.0, 0.0, 0.0)

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	var sprite: CanvasItem = attacker.get_visual_sprite()
	var orig_modulate: Color = sprite.self_modulate if sprite != null else Color.WHITE

	var beam_node := BeamVisual.new()
	beam_node.setup(beam_width, beam_color, core_color, show_charge_rings, beam_fade_out_time, beam_z_index)
	if charge_feedback_cue != null:
		GameFeedback.play_cue(charge_feedback_cue, null, attacker.global_position, attacker)

	spawn_ability_node(attacker, beam_node, attacker.global_position)

	var aim_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state

	# =========================================================
	# FAZA 1: CELOWANIE I KUMULOWANIE ENERGII (TELEGRAFOWANIE)
	# =========================================================
	var elapsed: float = 0.0
	while elapsed < cast_time:
		if not is_caster_active(attacker) or not is_instance_valid(target):
			_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, false)
			return

		if track_target_during_cast:
			var desired_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
			if desired_dir != Vector2.ZERO:
				aim_dir = aim_dir.lerp(desired_dir, tracking_smoothness).normalized()
				orient_towards(attacker, aim_dir)

		var ray_data: Dictionary = _trace_beam_endpoint(space_state, attacker, aim_dir)
		beam_node.update_beam_geometry(attacker.global_position, ray_data["end_pos"], bool(ray_data["hit_obstacle"]))

		var charge_progress: float = clampf(elapsed / maxf(MIN_DURATION_SEC, cast_time), 0.0, 1.0)
		beam_node.charge_progress = charge_progress

		if pulse_caster_during_cast and is_instance_valid(sprite) and not attacker.is_frozen:
			var pulse: float = (sin(elapsed * CHARGE_PULSE_SPEED_RAD) + 1.0) * 0.5
			sprite.self_modulate = orig_modulate.lerp(beam_color, pulse * charge_progress)

		if not is_caster_active(attacker):
			_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, false)
			return

		elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	if is_instance_valid(sprite) and not (is_caster_active(attacker) and attacker.is_frozen):
		sprite.self_modulate = orig_modulate

	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, false)
		return

	# =========================================================
	# FAZA 2: AKTYWNY STRZAŁ WIĄZKĄ I NAKŁADANIE EFEKTÓW
	# =========================================================
	beam_node.begin_firing()
	if fire_feedback_cue != null:
		GameFeedback.play_cue(fire_feedback_cue, null, attacker.global_position, attacker)

	var fire_elapsed: float = 0.0
	var next_damage_tick: float = 0.0
	var next_spark_tick: float = 0.0

	while fire_elapsed < beam_duration:
		if not is_caster_active(attacker):
			_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, true)
			return

		if track_target_during_fire and is_instance_valid(target):
			var desired_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
			if desired_dir != Vector2.ZERO:
				aim_dir = aim_dir.lerp(desired_dir, firing_tracking_smoothness).normalized()
				orient_towards(attacker, aim_dir)

		var start_pos: Vector2 = attacker.global_position
		var ray_data: Dictionary = _trace_beam_endpoint(space_state, attacker, aim_dir)
		var final_end_pos: Vector2 = ray_data["end_pos"]
		var hit_obstacle: bool = bool(ray_data["hit_obstacle"])
		beam_node.update_beam_geometry(start_pos, final_end_pos, hit_obstacle)

		if show_impact_sparks and hit_obstacle and fire_elapsed >= next_spark_tick:
			next_spark_tick += IMPACT_SPARK_INTERVAL_SEC
			CombatVFXHelper.spawn_impact_sparks(
				attacker,
				final_end_pos,
				-aim_dir,
				beam_color,
				IMPACT_SPARK_COUNT,
				beam_width * IMPACT_SPARK_RADIUS_MULT
			)

		if fire_elapsed >= next_damage_tick:
			next_damage_tick += damage_tick_rate
			_apply_beam_hit_tick(space_state, attacker, start_pos, final_end_pos, aim_dir)
			notify_components_area_detonated(attacker, final_end_pos, beam_width)

		if not is_caster_active(attacker):
			_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, true)
			return

		fire_elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	_finish_cast(attacker, combat_ctrl, sprite, orig_modulate, beam_node, true)

## Wyznacza punkt końcowy wiązki (z uwzględnieniem opcjonalnego przenikania przez przeszkody).
func _trace_beam_endpoint(
	space_state: PhysicsDirectSpaceState2D,
	attacker: CharacterEntity,
	aim_dir: Vector2
) -> Dictionary:
	var start_pos: Vector2 = attacker.global_position
	var max_end_pos: Vector2 = start_pos + (aim_dir * beam_range)
	if pierce_obstacles:
		return {"end_pos": max_end_pos, "hit_obstacle": false}

	var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start_pos, max_end_pos)
	ray_query.collision_mask = obstacles_mask
	ray_query.exclude = [attacker.get_rid()]
	var result: Dictionary = space_state.intersect_ray(ray_query)
	if not result.is_empty():
		return {"end_pos": result["position"], "hit_obstacle": true}
	return {"end_pos": max_end_pos, "hit_obstacle": false}

## Wykrywa wszystkie cele na obszarze prostokąta wiązki i nakłada efekty z AttackData + on_hit_effects + komponenty.
func _apply_beam_hit_tick(
	space_state: PhysicsDirectSpaceState2D,
	attacker: CharacterEntity,
	start_pos: Vector2,
	end_pos: Vector2,
	aim_dir: Vector2
) -> void:
	var beam_length: float = start_pos.distance_to(end_pos)
	if beam_length <= MIN_BEAM_LENGTH_PX:
		return

	var rect := RectangleShape2D.new()
	rect.size = Vector2(beam_length, beam_width)

	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = rect
	shape_query.transform = Transform2D(aim_dir.angle(), start_pos + ((end_pos - start_pos) * 0.5))
	shape_query.exclude = [attacker.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(shape_query, MAX_BEAM_HITS)
	if hits.is_empty():
		return

	var tick_effects: Array[Effect] = build_hit_effects(attacker)

	for hit in hits:
		var col: Node2D = hit["collider"] as Node2D
		if not _can_beam_hit_target(attacker, col):
			continue
		var hit_applied: bool = apply_effects_to_target(attacker, col, tick_effects, start_pos)
		notify_components_target_hit(attacker, col, start_pos)
		if hit_applied and show_impact_sparks:
			CombatVFXHelper.spawn_impact_sparks(
				attacker,
				col.global_position,
				-aim_dir,
				core_color,
				IMPACT_SPARK_COUNT,
				beam_width * IMPACT_SPARK_RADIUS_MULT
			)

func _can_beam_hit_target(attacker: CharacterEntity, target: Node2D) -> bool:
	match target_mode:
		BeamTargetMode.ENEMIES_ONLY:
			return can_affect_target(attacker, target, false, true, false)
		BeamTargetMode.ALLIES_ONLY:
			return can_affect_target(attacker, target, true, false, false)
		BeamTargetMode.EVERYONE:
			return can_affect_target(attacker, target, true, true, false)
	return false

## Bezpiecznie zamyka cykl życia wiązki i zawsze zwalnia blokadę is_casting_ability.
## Parametry typu Variant chronią przed błędem 'previously freed', gdy jednostka zginie w trakcie await!
func _finish_cast(
	attacker: Variant,
	combat_ctrl: Variant,
	sprite: Variant,
	orig_modulate: Color,
	beam_node: Variant,
	allow_fade_out: bool
) -> void:
	if is_instance_valid(sprite) and sprite is CanvasItem:
		(sprite as CanvasItem).self_modulate = orig_modulate
	if is_instance_valid(beam_node) and beam_node is BeamVisual:
		var visual: BeamVisual = beam_node as BeamVisual
		if allow_fade_out:
			visual.begin_fade_out()
		else:
			visual.queue_free()
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: 3-warstwowy renderer wiązki (Ładowanie -> Strzał -> Wygaszanie)
# ==============================================================================
class BeamVisual extends Node2D:
	enum VisualPhase { CHARGE, FIRE, FADE_OUT }

	const CHARGE_LINE_MIN_ALPHA: float = 0.28
	const CHARGE_LINE_MAX_ALPHA: float = 0.78
	const CHARGE_LINE_WIDTH_PX: float = 2.2
	const CHARGE_DASH_LENGTH_PX: float = 14.0
	const CHARGE_RING_COUNT: int = 2
	const CHARGE_RING_POINTS: int = 32
	const CHARGE_RING_MAX_MULT: float = 3.2
	const CHARGE_ORB_MIN_PX: float = 3.0
	const CHARGE_ORB_MAX_MULT: float = 2.0
	const CHARGE_ORB_CORE_RATIO: float = 0.48
	const CHARGE_PULSE_HZ: float = 20.0

	const FIRE_FLICKER_SPEED_RAD: float = 36.0
	const FIRE_FLICKER_AMPLITUDE: float = 0.14
	const OUTER_GLOW_WIDTH_MULT: float = 2.15
	const OUTER_GLOW_ALPHA: float = 0.30
	const CORE_WIDTH_MULT: float = 0.38
	const EMITTER_GLOW_MULT: float = 1.85
	const EMITTER_CORE_MULT: float = 0.85
	const IMPACT_GLOW_MULT: float = 1.65
	const IMPACT_CORE_MULT: float = 0.72
	const MIN_DRAW_LENGTH_PX: float = 1.0

	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2.ZERO
	var beam_width: float = 15.0
	var beam_color: Color = Color.RED
	var core_color: Color = Color.WHITE
	var show_charge_rings: bool = true
	var fade_out_duration: float = 0.18
	var charge_progress: float = 0.0

	var _phase: VisualPhase = VisualPhase.CHARGE
	var _time_elapsed: float = 0.0
	var _fade_elapsed: float = 0.0
	var _hit_obstacle: bool = false

	func setup(
		width: float,
		main_col: Color,
		inner_core_col: Color,
		enable_charge_rings: bool,
		fade_duration: float,
		z_layer: int
	) -> void:
		beam_width = width
		beam_color = main_col
		core_color = inner_core_col
		show_charge_rings = enable_charge_rings
		fade_out_duration = maxf(0.05, fade_duration)
		z_as_relative = false
		z_index = z_layer

	func update_beam_geometry(new_start: Vector2, new_end: Vector2, hit_obstacle: bool) -> void:
		start_pos = new_start
		end_pos = new_end
		_hit_obstacle = hit_obstacle

	func begin_firing() -> void:
		_phase = VisualPhase.FIRE

	func begin_fade_out() -> void:
		_phase = VisualPhase.FADE_OUT
		_fade_elapsed = 0.0

	func _process(delta: float) -> void:
		_time_elapsed += delta
		if _phase == VisualPhase.FADE_OUT:
			_fade_elapsed += delta
			if _fade_elapsed >= fade_out_duration:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var local_start: Vector2 = to_local(start_pos)
		var local_end: Vector2 = to_local(end_pos)

		match _phase:
			VisualPhase.CHARGE:
				_draw_charge_phase(local_start, local_end)
			VisualPhase.FIRE:
				_draw_active_beam(local_start, local_end, 1.0)
			VisualPhase.FADE_OUT:
				var fade_alpha: float = clampf(1.0 - (_fade_elapsed / fade_out_duration), 0.0, 1.0)
				_draw_active_beam(local_start, local_end, fade_alpha)

	func _draw_charge_phase(local_start: Vector2, local_end: Vector2) -> void:
		var pulse: float = (sin(_time_elapsed * CHARGE_PULSE_HZ) + 1.0) * 0.5
		if local_start.distance_to(local_end) > MIN_DRAW_LENGTH_PX:
			var aim_alpha: float = lerpf(CHARGE_LINE_MIN_ALPHA, CHARGE_LINE_MAX_ALPHA, charge_progress)
			var aim_col := Color(beam_color.r, beam_color.g, beam_color.b, aim_alpha)
			draw_dashed_line(
				local_start,
				local_end,
				aim_col,
				CHARGE_LINE_WIDTH_PX,
				CHARGE_DASH_LENGTH_PX,
				true,
				true
			)

		if show_charge_rings:
			for i in range(CHARGE_RING_COUNT):
				var ring_phase: float = fmod(charge_progress + (float(i) / float(CHARGE_RING_COUNT)), 1.0)
				var ring_radius: float = lerpf(beam_width * CHARGE_RING_MAX_MULT, beam_width * 0.4, ring_phase)
				var ring_col := Color(beam_color.r, beam_color.g, beam_color.b, ring_phase * 0.85)
				draw_arc(local_start, ring_radius, 0.0, TAU, CHARGE_RING_POINTS, ring_col, 2.0, true)

		var orb_radius: float = lerpf(CHARGE_ORB_MIN_PX, beam_width * CHARGE_ORB_MAX_MULT, charge_progress)
		var orb_col := Color(beam_color.r, beam_color.g, beam_color.b, lerpf(0.35, 0.92, pulse))
		draw_circle(local_start, orb_radius, orb_col)
		draw_circle(local_start, orb_radius * CHARGE_ORB_CORE_RATIO, core_color)

	func _draw_active_beam(local_start: Vector2, local_end: Vector2, intensity: float) -> void:
		var flicker: float = 1.0 + (sin(_time_elapsed * FIRE_FLICKER_SPEED_RAD) * FIRE_FLICKER_AMPLITUDE)
		var eff_width: float = beam_width * flicker * intensity

		var glow_col := Color(beam_color.r, beam_color.g, beam_color.b, OUTER_GLOW_ALPHA * intensity)
		var main_col := Color(beam_color.r, beam_color.g, beam_color.b, beam_color.a * intensity)
		var inner_col := Color(core_color.r, core_color.g, core_color.b, core_color.a * intensity)

		draw_line(local_start, local_end, glow_col, eff_width * OUTER_GLOW_WIDTH_MULT, true)
		draw_line(local_start, local_end, main_col, eff_width, true)
		draw_line(local_start, local_end, inner_col, eff_width * CORE_WIDTH_MULT, true)

		draw_circle(local_start, eff_width * EMITTER_GLOW_MULT, glow_col)
		draw_circle(local_start, eff_width * EMITTER_CORE_MULT, inner_col)

		var end_mult: float = 1.15 if _hit_obstacle else 0.90
		draw_circle(local_end, eff_width * IMPACT_GLOW_MULT * end_mult, main_col)
		draw_circle(local_end, eff_width * IMPACT_CORE_MULT * end_mult, inner_col)
