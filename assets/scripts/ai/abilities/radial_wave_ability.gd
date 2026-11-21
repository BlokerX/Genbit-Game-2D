extends AIAbility
class_name RadialWaveAbility
## Uniwersalny archetyp koncentrycznej fali obszarowej (SOLID - SRP / OCP / DRY).
## Wszystkie obrażenia, statusy (np. Freeze, Slow, ClearEffectsEffect, Heal) oraz zachowania specjalne
## (ScreenOverlayAbilityComponent, NpcAmnesiaAbilityComponent, CameraShakeAbilityComponent, AllyPulseAbilityComponent)
## konfiguruje się w pliku .tres bez wiązania skryptu z jednym konkretnym żywiołem.

## Określa, na jakie grupy postaci oddziałuje fala.
enum WaveTargetMode {
	ENEMIES_ONLY, ## Oddziałuje wyłącznie na wrogów.
	ALLIES_ONLY,  ## Oddziałuje wyłącznie na sojuszników (np. fala oczyszczająca lub lecząca).
	EVERYONE      ## Oddziałuje na wszystkie postacie w promieniu fali (friendly fire).
}

#region Stałe Domenowe (Brak magicznych liczb)
const MAX_WAVE_HITS: int = 32
const HALF_CAST_FACTOR: float = 0.5
const DEFAULT_WAVE_MAX_RANGE: float = 700.0
#endregion

@export_category("Archetyp: Koncentryczna Fala Obszarowa (RadialWaveAbility)")

@export_group("Zasięg, Czas Ładowania i Cele")
## Czas ładowania fali przed uderzeniem (w sekundach).
@export_range(0.1, 5.0, 0.1) var cast_time: float = 1.2
## Promień uderzenia fali obszarowej (w pikselach).
@export_range(50.0, 1500.0, 10.0) var blast_radius: float = 450.0
## Określa, które jednostki są obejmowane działaniem fali (wrogowie, sojusznicy lub wszyscy).
@export var target_mode: WaveTargetMode = WaveTargetMode.ENEMIES_ONLY
## Czy fala ma oddziaływać również na samego rzucającego (np. fala oczyszczająca)?
@export var include_caster: bool = false

@export_group("Wizualizacje Fali (VFX)")
## Główny kolor pierścieni i aury fali (np. fiolet psychozy, biel oczyszczenia, błękit mrozu).
@export var aura_color: Color = Color(0.45, 0.08, 0.88, 0.72)
## Liczba przesuniętych w fazie koncentrycznych pierścieni rysowanych podczas ładowania i eksplozji.
@export_range(1, 5, 1) var wave_ring_count: int = 3
## Mnożnik chwilowego pulsowania skali rzucającego w trakcie ładowania fali.
@export_range(1.0, 2.5, 0.05) var visual_scale_pulse: float = 1.25
## Czas rozchodzenia się i zanikania fali po wybuchu (w sekundach).
@export_range(0.1, 2.0, 0.05) var explosion_fade_time: float = 0.8
## Warstwa renderowania (Z-Index) fali na mapie (domyślnie nad podłogą / pod postaciami).
@export var wave_z_index: int = GameLayers.FLOOR_HAZARD + 5

func _init() -> void:
	ability_name = "Fala Obszarowa"
	cooldown = 18.0
	min_range = 0.0
	max_range = DEFAULT_WAVE_MAX_RANGE
	damage_category = Effect.EffectCategory.MENTAL_PSYCHOSIS

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	# 1. Wielopierścieniowa wizualizacja fali wokół atakującego
	var wave_visual := RadialWaveVisual.new()
	wave_visual.setup(attacker, blast_radius, aura_color, cast_time, explosion_fade_time, wave_ring_count, wave_z_index)
	spawn_ability_node(attacker, wave_visual, attacker.global_position)

	# Pulsowanie skali w oparciu o bezpieczne base_scale
	var tween: Tween = attacker.create_tracked_tween()
	var orig_scale: Vector2 = attacker.base_scale
	tween.tween_property(attacker, "scale", orig_scale * visual_scale_pulse, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)
	tween.tween_property(attacker, "scale", orig_scale, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)

	if not is_caster_active(attacker):
		_cleanup_cast(attacker, combat_ctrl, wave_visual, true)
		return

	# 2. Faza ładowania fali
	await attacker.get_tree().create_timer(cast_time).timeout

	if not is_caster_active(attacker):
		_cleanup_cast(attacker, combat_ctrl, wave_visual, true)
		return

	attacker.reset_visual_scale()

	# 3. Uderzenie fali i aplikacja efektów z jednolitego kontraktu AIAbility + komponentów
	if is_instance_valid(wave_visual):
		wave_visual.explode()
	CombatVFXHelper.spawn_shockwave(attacker, attacker.global_position, blast_radius, aura_color)
	notify_components_area_detonated(attacker, attacker.global_position, blast_radius)

	var hits: Array[Dictionary] = _query_targets_in_radius(attacker)
	var hit_effects: Array[Effect] = build_hit_effects(attacker)

	if include_caster:
		apply_effects_to_target(attacker, attacker, hit_effects, attacker.global_position)
		notify_components_target_hit(attacker, attacker, attacker.global_position)

	for hit in hits:
		var col: Node2D = hit["collider"] as Node2D
		if not _can_wave_hit_target(attacker, col):
			continue
		apply_effects_to_target(attacker, col, hit_effects, attacker.global_position)
		notify_components_target_hit(attacker, col, attacker.global_position)

	_cleanup_cast(attacker, combat_ctrl, wave_visual, false)

func _query_targets_in_radius(attacker: CharacterEntity) -> Array[Dictionary]:
	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, attacker.global_position)
	query.exclude = [attacker.get_rid()]
	return space_state.intersect_shape(query, MAX_WAVE_HITS)

func _can_wave_hit_target(attacker: CharacterEntity, target: Node2D) -> bool:
	match target_mode:
		WaveTargetMode.ENEMIES_ONLY:
			return can_affect_target(attacker, target, false, true, false)
		WaveTargetMode.ALLIES_ONLY:
			return can_affect_target(attacker, target, true, false, false)
		WaveTargetMode.EVERYONE:
			return can_affect_target(attacker, target, true, true, false)
	return false

## Bezpiecznie kończy rzucanie fali (parametry Variant chronią przed błędem 'previously freed' po await).
func _cleanup_cast(
	attacker: Variant,
	combat_ctrl: Variant,
	wave_visual: Variant,
	destroy_visual: bool
) -> void:
	if is_instance_valid(attacker) and attacker is CharacterEntity:
		(attacker as CharacterEntity).reset_visual_scale()
	if destroy_visual and is_instance_valid(wave_visual) and wave_visual is Node:
		(wave_visual as Node).queue_free()
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Wielopierścieniowa fala ładowania i eksplozji
# ==============================================================================
class RadialWaveVisual extends Node2D:
	const RING_POINTS: int = 64
	const MIN_TIME_SEC: float = 0.01
	const CHARGE_PULSE_SPEED_RAD: float = 15.0
	const CHARGE_FILL_MIN_ALPHA: float = 0.08
	const CHARGE_FILL_MAX_ALPHA: float = 0.24
	const BOUNDARY_OUTLINE_WIDTH_PX: float = 2.0
	const BOUNDARY_OUTLINE_ALPHA: float = 0.55
	const EXPLOSION_EXTRA_RADIUS_PX: float = 85.0
	const EXPLOSION_START_WIDTH_PX: float = 5.5
	const EXPLOSION_END_WIDTH_PX: float = 1.2
	const CORE_RING_LIGHTEN: float = 0.45

	var _target_node: Node2D = null
	var _radius: float = 300.0
	var _color: Color = Color.PURPLE
	var _cast_time: float = 1.0
	var _fade_time: float = 0.6
	var _ring_count: int = 3
	var _elapsed: float = 0.0
	var _exploded: bool = false
	var _post_explode_timer: float = 0.0

	func setup(
		target: Node2D,
		wave_radius: float,
		wave_color: Color,
		cast_dur: float,
		fade_dur: float,
		rings: int,
		z_layer: int
	) -> void:
		_target_node = target
		_radius = wave_radius
		_color = wave_color
		_cast_time = maxf(MIN_TIME_SEC, cast_dur)
		_fade_time = maxf(MIN_TIME_SEC, fade_dur)
		_ring_count = maxi(1, rings)
		z_as_relative = false
		z_index = z_layer

	func explode() -> void:
		_exploded = true

	func _process(delta: float) -> void:
		if is_instance_valid(_target_node):
			global_position = _target_node.global_position

		if not _exploded:
			_elapsed += delta
		else:
			_post_explode_timer += delta
			if _post_explode_timer >= _fade_time:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		if not _exploded:
			_draw_charging_rings()
		else:
			_draw_exploding_rings()

	func _draw_charging_rings() -> void:
		var progress: float = clampf(_elapsed / _cast_time, 0.0, 1.0)
		var pulse: float = (sin(_elapsed * CHARGE_PULSE_SPEED_RAD) + 1.0) * 0.5
		var fill_alpha: float = lerpf(CHARGE_FILL_MIN_ALPHA, CHARGE_FILL_MAX_ALPHA, pulse) * progress

		draw_circle(Vector2.ZERO, _radius * progress, Color(_color.r, _color.g, _color.b, fill_alpha))
		draw_arc(
			Vector2.ZERO,
			_radius,
			0.0,
			TAU,
			RING_POINTS,
			Color(_color.r, _color.g, _color.b, BOUNDARY_OUTLINE_ALPHA * progress),
			BOUNDARY_OUTLINE_WIDTH_PX,
			true
		)

		for i in range(_ring_count):
			var phase: float = fmod(progress + (float(i) / float(_ring_count)), 1.0)
			var ring_radius: float = _radius * (1.0 - phase)
			var ring_alpha: float = sin(phase * PI) * 0.78
			draw_arc(
				Vector2.ZERO,
				ring_radius,
				0.0,
				TAU,
				RING_POINTS,
				Color(_color.r, _color.g, _color.b, ring_alpha),
				2.4,
				true
			)

	func _draw_exploding_rings() -> void:
		var progress: float = clampf(_post_explode_timer / _fade_time, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var fade: float = 1.0 - progress

		draw_circle(
			Vector2.ZERO,
			_radius + (EXPLOSION_EXTRA_RADIUS_PX * eased),
			Color(_color.r, _color.g, _color.b, 0.35 * fade)
		)

		var core_col: Color = _color.lightened(CORE_RING_LIGHTEN)
		for i in range(_ring_count):
			var offset_ratio: float = float(i) * 0.14
			var ring_progress: float = clampf(eased - offset_ratio, 0.0, 1.0)
			var ring_radius: float = lerpf(_radius * 0.35, _radius + EXPLOSION_EXTRA_RADIUS_PX, ring_progress)
			var width: float = lerpf(EXPLOSION_START_WIDTH_PX, EXPLOSION_END_WIDTH_PX, progress)
			var ring_col: Color = core_col if i == 0 else _color
			draw_arc(
				Vector2.ZERO,
				ring_radius,
				0.0,
				TAU,
				RING_POINTS,
				Color(ring_col.r, ring_col.g, ring_col.b, fade * 0.90),
				width,
				true
			)
