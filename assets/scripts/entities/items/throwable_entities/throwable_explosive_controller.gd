class_name ThrowableExplosiveController
extends RefCounted
## Wspólny kontroler logiki zapalnika, animowanego spalania wzdłuż ścieżki knota, wybuchu obszarowego (AoE),
## obsługi efektów (Trigger/Damage/Knockback), weryfikacji sojuszników oraz proceduralnych VFX
## dla ThrowablePhysics i ThrowableProjectile. Realizuje zasady Single Responsibility (SRP), OCP i DRY.

#region Stałe Fizyczne i Wizualne (Brak magicznych liczb)
const SELF_HIT_GRACE_TIME_SEC: float = 0.1

const DEFAULT_EXPLOSION_RADIUS_PX: float = 80.0
const DEFAULT_EXPLOSION_PRIMARY_COLOR := Color(1.0, 0.45, 0.12, 0.95)
const EXPLOSION_CORE_LIGHTEN: float = 0.58
const EXPLOSION_BASE_DURATION_SEC: float = 0.36

const DIRECT_IMPACT_DEFAULT_COLOR := Color(0.95, 0.92, 0.82, 0.95)
const DIRECT_IMPACT_SPARK_COUNT: int = 7
const DIRECT_IMPACT_SPARK_RADIUS_PX: float = 20.0

const FUSE_IGNITE_COLOR := Color(1.0, 0.84, 0.25, 0.95)
const FUSE_URGENT_COLOR := Color(1.0, 0.42, 0.12, 0.98)
const FUSE_IGNITE_SPARK_COUNT: int = 8
const FUSE_IGNITE_SPARK_RADIUS_PX: float = 22.0
const FUSE_ARMED_RING_RADIUS_PX: float = 26.0
const FUSE_ARMED_RING_DURATION_SEC: float = 0.24
const FUSE_ARMED_RING_FILL_ALPHA: float = 0.12
const FUSE_TICK_SPARK_INTERVAL_SEC: float = 0.13
const FUSE_URGENT_SPARK_INTERVAL_SEC: float = 0.06
const FUSE_URGENT_PROGRESS_THRESHOLD: float = 0.70
const FUSE_TICK_SPARK_COUNT: int = 4
const FUSE_TICK_SPARK_RADIUS_PX: float = 15.0
const FUSE_TICK_SPARK_DURATION_SEC: float = 0.16

const EXPLOSION_SHAKE_REFERENCE_RADIUS_PX: float = 120.0
const EXPLOSION_SHAKE_MIN_TRAUMA: float = 0.22
const EXPLOSION_SHAKE_MAX_TRAUMA: float = 0.65
const EXPLOSION_SHAKE_MAX_DISTANCE_PX: float = 950.0
#endregion

var shooter_faction_name: StringName = &""
var time_alive: float = 0.0
var is_fuse_lit: bool = false
var fuse_timer: float = 0.0
var _fuse_spark_timer: float = 0.0
var _direct_hit_ref: WeakRef = null
var _fuse_flame_ref: WeakRef = null

## Zapisuje nazwę frakcji strzelca w momencie utworzenia rzutki (chroni przed błędem, gdy strzelec zginie przed wybuchem).
func cache_shooter_faction(shooter: Variant) -> void:
	if is_instance_valid(shooter) and shooter is Node:
		var my_faction: FactionComponent = (shooter as Node).get_node_or_null("FactionComponent") as FactionComponent
		if my_faction != null:
			shooter_faction_name = my_faction.faction_name

## Wyzwala początkowy rozbłysk zapalenia na początku ścieżki knota (lub w środku dla miny) i tworzy płomień (SRP).
func play_fuse_ignition_vfx(host: Node2D, fuse_path_points: PackedVector2Array = PackedVector2Array()) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	var sample: Dictionary = sample_fuse_path(fuse_path_points, 0.0)
	var local_pos: Vector2 = sample["pos"]
	var local_dir: Vector2 = sample["dir"]

	_update_fuse_flame_node(host, local_pos, 0.0, false)

	var world_pos: Vector2 = host.global_position + local_pos.rotated(host.global_rotation)
	var world_dir: Vector2 = local_dir.rotated(host.global_rotation) if local_dir.length_squared() > 0.001 else Vector2.ZERO
	CombatVFXHelper.spawn_impact_sparks(
		host,
		world_pos,
		world_dir,
		FUSE_IGNITE_COLOR,
		FUSE_IGNITE_SPARK_COUNT,
		FUSE_IGNITE_SPARK_RADIUS_PX
	)

## Aktualizuje czas życia obiektu, przesuwa animowany płomień po knocie, generuje iskry i odlicza zapalnik.
## Zwraca true, jeśli obiekt przekroczył swój czas życia i został zdetonowany.
func process_timers(
	host: Node2D,
	delta: float,
	lifetime: float,
	is_infinite: bool,
	activation_delay: float,
	emit_countdown_sparks: bool = false,
	fuse_path_points: PackedVector2Array = PackedVector2Array()
) -> bool:
	time_alive += delta
	if not is_infinite and time_alive >= lifetime:
		if host.has_method("trigger_effect"):
			host.call("trigger_effect", null)
		return true

	if is_fuse_lit:
		fuse_timer += delta
		var fuse_progress: float = clampf(fuse_timer / maxf(0.01, activation_delay), 0.0, 1.0)
		_process_fuse_burn_vfx(host, delta, fuse_progress, fuse_path_points)

		if fuse_timer >= activation_delay:
			is_fuse_lit = false
			var live_direct_hit: Node2D = _resolve_direct_hit()
			if host.has_method("_execute_explosion"):
				host.call("_execute_explosion", live_direct_hit)
	elif emit_countdown_sparks and not is_infinite and lifetime > 0.0:
		var life_progress: float = clampf(time_alive / lifetime, 0.0, 1.0)
		_process_fuse_burn_vfx(host, delta, life_progress, fuse_path_points)

	return false

## Obsługuje uzbrojenie zapalnika (z rozbłyskiem, płomieniem/diodą i iskrami w punkcie knota/środka) lub natychmiastową detonację.
func handle_trigger(
	host: Node2D,
	shooter: Variant,
	direct_hit: Variant,
	friendly_fire: bool,
	activation_delay: float,
	main_sprite: Sprite2D,
	activated_texture: Texture2D,
	fuse_path_points: PackedVector2Array = PackedVector2Array()
) -> void:
	if not is_instance_valid(host):
		return

	var valid_shooter: Node2D = shooter as Node2D if is_instance_valid(shooter) and shooter is Node2D else null
	var valid_direct_hit: Node2D = direct_hit as Node2D if is_instance_valid(direct_hit) and direct_hit is Node2D else null

	# Ochrona przed natychmiastowym trafieniem samego strzelca w ułamku sekundy po rzucie
	if valid_shooter != null and valid_direct_hit == valid_shooter:
		if not friendly_fire or time_alive < SELF_HIT_GRACE_TIME_SEC:
			return

	if host.is_queued_for_deletion() or host.has_meta("is_triggered"):
		return
	host.set_meta("is_triggered", true)

	if main_sprite != null and activated_texture != null:
		main_sprite.texture = activated_texture

	if activation_delay > 0.0 and valid_direct_hit == null:
		is_fuse_lit = true
		fuse_timer = 0.0
		_fuse_spark_timer = 0.0
		_direct_hit_ref = null

		var sample: Dictionary = sample_fuse_path(fuse_path_points, 0.0)
		var ring_world_pos: Vector2 = host.global_position + (sample["pos"] as Vector2).rotated(host.global_rotation)
		CombatVFXHelper.spawn_shockwave(
			host,
			ring_world_pos,
			FUSE_ARMED_RING_RADIUS_PX,
			FUSE_IGNITE_COLOR,
			FUSE_ARMED_RING_DURATION_SEC,
			GameLayers.FX,
			FUSE_ARMED_RING_FILL_ALPHA
		)
		play_fuse_ignition_vfx(host, fuse_path_points)
	else:
		_direct_hit_ref = weakref(valid_direct_hit) if valid_direct_hit != null else null
		if host.has_method("_execute_explosion"):
			host.call("_execute_explosion", valid_direct_hit)

## Zbiera wszystkie cele w strefie rażenia (aoe_area lub fallback_area), filtruje sojuszników,
## generuje odpowiedni efekt VFX (eksplozję AoE lub iskry impaktu) i nakłada efekty.
func execute_explosion(
	host: Node2D,
	shooter: Variant,
	direct_hit: Variant,
	aoe_area: Area2D,
	fallback_area: Area2D,
	friendly_fire: bool,
	effects_to_apply: Array[Effect],
	warn_on_missing_aoe: bool = false
) -> void:
	if not is_instance_valid(host):
		return

	var valid_shooter: Node2D = shooter as Node2D if is_instance_valid(shooter) and shooter is Node2D else null
	var valid_direct_hit: Node2D = direct_hit as Node2D if is_instance_valid(direct_hit) and direct_hit is Node2D else null

	var targets: Array[Node2D] = []
	var source_area: Area2D = aoe_area if aoe_area != null else fallback_area

	if source_area != null:
		targets.append_array(source_area.get_overlapping_bodies())
		for area in source_area.get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
	elif warn_on_missing_aoe:
		push_warning("BŁĄD: %s wybuchł, ale nie ma przypisanego 'aoe_area' w Inspektorze!" % host.name)

	if valid_direct_hit != null and not targets.has(valid_direct_hit):
		targets.append(valid_direct_hit)

	_spawn_detonation_vfx(host, source_area, effects_to_apply)

	for body in targets:
		if not is_instance_valid(body):
			continue
		if valid_shooter != null and body == valid_shooter and not friendly_fire:
			continue
		if not friendly_fire and FactionComponent.is_ally_of(valid_shooter, body, shooter_faction_name):
			continue

		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				if effect != null:
					var cloned_eff: Effect = effect.duplicate(true) as Effect
					cloned_eff.source_position = host.global_position
					cloned_eff.source_entity = valid_shooter
					body.receive_effect(cloned_eff)

	host.queue_free()

## Wspólna obsługa odbierania efektów zewnętrznych (detonacja łańcuchowa od wybuchu, obrażeń lub odrzut).
func handle_received_effect(
	host: Node2D,
	effect: Effect,
	activate_on_trigger: bool,
	activate_on_damage: bool,
	can_be_knocked_back: bool
) -> bool:
	if not is_instance_valid(host) or effect == null:
		return false

	if effect is TriggerEffect:
		if activate_on_trigger and not host.is_queued_for_deletion():
			host.call("trigger_effect", null)
		return true

	if effect is DamageEffect:
		if activate_on_damage and not host.is_queued_for_deletion():
			host.call("trigger_effect", null)
		return true

	if effect is KnockbackEffect:
		if not can_be_knocked_back:
			return true
		return effect.apply_effect(host)

	return effect.apply_effect(host)

# =========================================================================
# INTERPOLACJA ŚCIEŻKI KNOTA I PŁOMIEŃ (SRP / OCP / DRY)
# =========================================================================

## Próbkuje pozycję lokalną oraz kierunek iskier wzdłuż zdefiniowanej ścieżki knota dla postępu 0.0..1.0.
## Gdy ścieżka jest pusta (np. Mina), zwraca środek (0, 0) oraz kierunek ZERO (iskry 360° wokół diody).
static func sample_fuse_path(path_points: PackedVector2Array, progress: float) -> Dictionary:
	var count: int = path_points.size()
	if count == 0:
		return {"pos": Vector2.ZERO, "dir": Vector2.ZERO}
	if count == 1:
		var pt: Vector2 = path_points[0]
		return {"pos": pt, "dir": pt.normalized() if pt.length_squared() > 0.001 else Vector2.ZERO}

	var total_length: float = 0.0
	for i in range(count - 1):
		total_length += path_points[i].distance_to(path_points[i + 1])

	if total_length <= 0.001:
		var first_pt: Vector2 = path_points[0]
		return {"pos": first_pt, "dir": Vector2.UP}

	var target_dist: float = clampf(progress, 0.0, 1.0) * total_length
	var accumulated: float = 0.0
	for i in range(count - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var seg_len: float = a.distance_to(b)
		if accumulated + seg_len >= target_dist or i == count - 2:
			var seg_t: float = clampf((target_dist - accumulated) / maxf(0.001, seg_len), 0.0, 1.0)
			var pos: Vector2 = a.lerp(b, seg_t)
			# Iskry odskakują na zewnątrz (od spalonej części w stronę czubka knota)
			var outward_dir: Vector2 = b.direction_to(a)
			return {"pos": pos, "dir": outward_dir}
		accumulated += seg_len

	return {"pos": path_points[count - 1], "dir": Vector2.UP}

## Aktualizuje pozycję animowanego płomienia na knocie oraz generuje cykliczne iskry z dokładnego miejsca spalania.
func _process_fuse_burn_vfx(
	host: Node2D,
	delta: float,
	progress: float,
	fuse_path_points: PackedVector2Array
) -> void:
	if not is_instance_valid(host):
		return

	var is_urgent: bool = progress >= FUSE_URGENT_PROGRESS_THRESHOLD
	var sample: Dictionary = sample_fuse_path(fuse_path_points, progress)
	var local_pos: Vector2 = sample["pos"]
	var local_dir: Vector2 = sample["dir"]

	_update_fuse_flame_node(host, local_pos, progress, is_urgent)

	var interval: float = FUSE_URGENT_SPARK_INTERVAL_SEC if is_urgent else FUSE_TICK_SPARK_INTERVAL_SEC
	_fuse_spark_timer += delta
	if _fuse_spark_timer < interval:
		return
	_fuse_spark_timer = 0.0

	var spark_color: Color = FUSE_URGENT_COLOR if is_urgent else FUSE_IGNITE_COLOR
	var world_pos: Vector2 = host.global_position + local_pos.rotated(host.global_rotation)
	var world_dir: Vector2 = local_dir.rotated(host.global_rotation) if local_dir.length_squared() > 0.001 else Vector2.ZERO
	CombatVFXHelper.spawn_impact_sparks(
		host,
		world_pos,
		world_dir,
		spark_color,
		FUSE_TICK_SPARK_COUNT,
		FUSE_TICK_SPARK_RADIUS_PX,
		FUSE_TICK_SPARK_DURATION_SEC
	)

## Tworzy (leniwie) i aktualizuje lekki węzeł płomienia spalania podpięty jako dziecko obiektu (znika automatycznie przy wybuchu).
func _update_fuse_flame_node(host: Node2D, local_pos: Vector2, progress: float, is_urgent: bool) -> void:
	var flame: _FuseFlameVFX = null
	if _fuse_flame_ref != null:
		var candidate: Variant = _fuse_flame_ref.get_ref()
		if is_instance_valid(candidate) and candidate is _FuseFlameVFX:
			flame = candidate as _FuseFlameVFX

	if flame == null:
		flame = _FuseFlameVFX.new()
		flame.name = "FuseFlameVFX"
		host.add_child(flame)
		_fuse_flame_ref = weakref(flame)

	flame.update_state(local_pos, progress, is_urgent)

# =========================================================================
# METODY POMOCNICZE VFX I GEOMETRII (SRP / DRY)
# =========================================================================

## Dobiera właściwy efekt wizualny (wielowarstwowy wybuch dla AoE lub iskry dla rzutki punktowej, np. noża).
func _spawn_detonation_vfx(host: Node2D, source_area: Area2D, effects_to_apply: Array[Effect]) -> void:
	if source_area != null:
		var explosion_radius: float = _resolve_area_radius(source_area)
		var primary_color: Color = CombatVFXHelper.resolve_color_from_effects(
			effects_to_apply,
			DEFAULT_EXPLOSION_PRIMARY_COLOR
		)
		var core_color: Color = primary_color.lightened(EXPLOSION_CORE_LIGHTEN)
		CombatVFXHelper.spawn_explosion(
			host,
			host.global_position,
			explosion_radius,
			primary_color,
			core_color,
			EXPLOSION_BASE_DURATION_SEC
		)
		_trigger_attenuated_explosion_shake(host, explosion_radius)
		return

	var spark_color: Color = CombatVFXHelper.resolve_color_from_effects(
		effects_to_apply,
		DIRECT_IMPACT_DEFAULT_COLOR
	)
	CombatVFXHelper.spawn_impact_sparks(
		host,
		host.global_position,
		Vector2.ZERO,
		spark_color,
		DIRECT_IMPACT_SPARK_COUNT,
		DIRECT_IMPACT_SPARK_RADIUS_PX
	)

## Odczytuje rzeczywisty promień wybuchu z kształtu kolizji przypisanego do Area2D (Information Expert).
func _resolve_area_radius(area: Area2D) -> float:
	if not is_instance_valid(area):
		return DEFAULT_EXPLOSION_RADIUS_PX
	for child in area.get_children():
		if not (child is CollisionShape2D):
			continue
		var col: CollisionShape2D = child as CollisionShape2D
		if col.shape == null:
			continue
		var scale_mult: float = maxf(absf(col.global_scale.x), absf(col.global_scale.y))
		if col.shape is CircleShape2D:
			return (col.shape as CircleShape2D).radius * scale_mult
		if col.shape is CapsuleShape2D:
			var cap: CapsuleShape2D = col.shape as CapsuleShape2D
			return maxf(cap.radius, cap.height * 0.5) * scale_mult
		if col.shape is RectangleShape2D:
			return (col.shape as RectangleShape2D).size.length() * 0.5 * scale_mult
	return DEFAULT_EXPLOSION_RADIUS_PX

## Wyzwala wstrząs kamery proporcjonalny do promienia wybuchu i tłumiony odległością od gracza.
func _trigger_attenuated_explosion_shake(host: Node2D, explosion_radius: float) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var player: Node2D = tree.get_first_node_in_group("Player") as Node2D
	if not is_instance_valid(player):
		return

	var dist: float = host.global_position.distance_to(player.global_position)
	if dist >= EXPLOSION_SHAKE_MAX_DISTANCE_PX:
		return

	var distance_factor: float = 1.0 - (dist / EXPLOSION_SHAKE_MAX_DISTANCE_PX)
	var size_ratio: float = clampf(explosion_radius / EXPLOSION_SHAKE_REFERENCE_RADIUS_PX, 0.5, 1.5)
	var base_trauma: float = clampf(EXPLOSION_SHAKE_MIN_TRAUMA * size_ratio, EXPLOSION_SHAKE_MIN_TRAUMA, EXPLOSION_SHAKE_MAX_TRAUMA)
	AIAbility.trigger_camera_shake(host, base_trauma * distance_factor)

func _resolve_direct_hit() -> Node2D:
	if _direct_hit_ref == null:
		return null
	var candidate: Variant = _direct_hit_ref.get_ref()
	if is_instance_valid(candidate) and candidate is Node2D:
		return candidate as Node2D
	return null

# ==============================================================================
# KLASA WEWNĘTRZNA: Migoczący płomień / żar przesuwający się wzdłuż knota (SRP)
# ==============================================================================
class _FuseFlameVFX extends Node2D:
	const BASE_RADIUS_PX: float = 7.0
	const URGENT_RADIUS_MULT: float = 1.35
	const FLICKER_SPEED_RAD: float = 38.0
	const FLICKER_AMPLITUDE: float = 0.22
	const OUTER_GLOW_COLOR := Color(1.0, 0.36, 0.08, 0.50)
	const MID_FLAME_COLOR := Color(1.0, 0.78, 0.16, 0.90)
	const CORE_FLAME_COLOR := Color(1.0, 0.98, 0.86, 0.98)
	const MID_RADIUS_RATIO: float = 0.65
	const CORE_RADIUS_RATIO: float = 0.34
	const STAR_RAY_MULT: float = 1.45
	const STAR_RAY_WIDTH_PX: float = 1.8

	var _time: float = 0.0
	var _progress: float = 0.0
	var _is_urgent: bool = false

	func _ready() -> void:
		z_as_relative = false
		z_index = GameLayers.FX

	func update_state(local_pos: Vector2, progress: float, is_urgent: bool) -> void:
		position = local_pos
		_progress = progress
		_is_urgent = is_urgent

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flicker: float = 1.0 + (sin(_time * FLICKER_SPEED_RAD) * FLICKER_AMPLITUDE)
		var radius: float = BASE_RADIUS_PX * lerpf(0.95, URGENT_RADIUS_MULT, _progress) * flicker

		draw_circle(Vector2.ZERO, radius, OUTER_GLOW_COLOR)
		draw_circle(Vector2.ZERO, radius * MID_RADIUS_RATIO, MID_FLAME_COLOR)
		draw_circle(Vector2.ZERO, radius * CORE_RADIUS_RATIO, CORE_FLAME_COLOR)

		# Ostra iskra krzyżowa pulsująca na końcu odliczania
		var ray_len: float = radius * (STAR_RAY_MULT if _is_urgent else 1.05)
		var rot_offset: float = _time * 4.5
		var axis_a: Vector2 = Vector2.from_angle(rot_offset) * ray_len
		var axis_b: Vector2 = Vector2.from_angle(rot_offset + (PI * 0.5)) * ray_len
		draw_line(-axis_a, axis_a, CORE_FLAME_COLOR, STAR_RAY_WIDTH_PX, true)
		draw_line(-axis_b, axis_b, CORE_FLAME_COLOR, STAR_RAY_WIDTH_PX, true)
