extends AIAbility
class_name ThrownZoneAbility
## Uniwersalny archetyp rzucanego pocisku tworzącego na ziemi aktywną, organiczną strefę (SOLID - SRP / OCP / DRY).
## Pozwala tworzyć w plikach .tres dowolne strefy (kałuża kwasu, plama lawy, strefa mrozu lub pole leczenia sojuszników).
## Uderzenie pocisku korzysta z głównego AttackData + on_hit_effects, natomiast sama strefa na ziemi
## z niezależnych zone_tick_attack_data + zone_tick_effects.
## Kształt strefy buforuje kolizje ze ścianami (0 raycastów/klatkę po rozlaniu) i zamraża geometrię dla statycznych plam.

## Określa, na jakie grupy postaci oddziałuje rozlana strefa oraz uderzenie pocisku.
enum ZoneTargetMode {
	ENEMIES_ONLY, ## Rani/nakłada efekty wyłącznie na wrogów.
	ALLIES_ONLY,  ## Nakłada efekty wyłącznie na sojuszników (np. rzucone pole leczenia).
	EVERYONE      ## Oddziałuje na wszystkie postacie w zasięgu (friendly fire).
}

#region Stałe Domenowe (Brak magicznych liczb)
const MAX_ZONE_TARGETS: int = 32
const IMPACT_RADIUS_MULTIPLIER: float = 1.5
const DEFAULT_THROW_MAX_RANGE: float = 700.0
const TELEGRAPH_ROTATION_TIME_RATIO: float = 0.80
const TELEGRAPH_TINT_WEIGHT: float = 0.70
#endregion

@export_category("Archetyp: Rzucana Strefa Obszarowa (ThrownZoneAbility)")

@export_group("Czasy Trwania, Zasięg i Przeszkody")
## Czas telegrafowania (przygotowania rzutu) przed wypuszczeniem pocisku (w sekundach).
@export_range(0.1, 3.0, 0.05) var telegraph_time: float = 1.3
## Czas lotu pocisku od rzucającego do punktu lądowania (w sekundach).
@export_range(0.1, 3.0, 0.05) var flight_time: float = 1.0
## Przewidywanie ruchu celu (0.0 = celuje w bieżącą pozycję, 1.0 = silne wyprzedzenie).
@export_range(0.0, 1.5, 0.1) var prediction_factor: float = 0.6
## Maska fizyki dla ścian i przeszkód zatrzymujących lot pocisku oraz ograniczających rozlewanie strefy.
@export_flags_2d_physics var obstacles_mask: int = 1

@export_group("Obszar Strefy i Dobór Celów")
## Promień fizyczny i wizualny kuli w trakcie lotu (w pikselach).
@export_range(8.0, 100.0, 2.0) var projectile_radius: float = 20.0
## Maksymalny promień rozlanej strefy na ziemi (w pikselach).
@export_range(30.0, 800.0, 10.0) var zone_radius: float = 220.0
## Czas (w sekundach), przez jaki rozlana strefa utrzymuje się na ziemi.
@export_range(1.0, 30.0, 0.5) var zone_lifetime: float = 7.0
## Jak często (w sekundach) strefa aplikuje swoje efekty na cele stojące w środku.
@export_range(0.1, 3.0, 0.1) var zone_tick_rate: float = 0.5
## Określa, na jakie frakcje oddziałuje uderzenie pocisku oraz rozlana strefa.
@export var target_mode: ZoneTargetMode = ZoneTargetMode.ENEMIES_ONLY
## Czy strefa ma oddziaływać również na samego rzucającego (np. własna strefa leczenia)?
@export var include_caster: bool = false

@export_group("Skutki Strefy na Ziemi (Konfiguracja w .tres)")
## Opcjonalny zasób AttackData dla każdego tiku samej strefy (np. bezpośrednie obrażenia od lawy na tick).
## Pozostaw null, jeśli strefa ma nakładać wyłącznie statusy z zone_tick_effects (np. PoisonDebuffEffect, SlowEffect).
@export var zone_tick_attack_data: AttackData = null
## Kategoria żywiołu dla bezpośrednich obrażeń z zone_tick_attack_data.
@export var zone_tick_damage_category: Effect.EffectCategory = Effect.EffectCategory.POISON_ACID
## Otwarta lista efektów nakładanych cyklicznie (co zone_tick_rate) na cele stojące w rozlanej strefie (OCP).
@export var zone_tick_effects: Array[Effect] = []

@export_group("Wizualizacje, Kształt Strefy i Warstwy (VFX)")
## Główny kolor pocisku i strefy (np. głęboka toksyczna zieleń kwasu, pomarańcz lawy, błękit lodu).
@export var zone_color: Color = Color(0.16, 0.72, 0.12, 0.82)
## Warstwa renderowania (Z-Index) dla rozlanej strefy na ziemi (domyślnie GameLayers.FLOOR_HAZARD).
@export var zone_z_index: int = GameLayers.FLOOR_HAZARD
## Częstotliwość szumu krawędzi (niższa wartość = łagodniejsze, naturalne łuki brzegowe).
@export_range(0.005, 0.1, 0.005) var noise_frequency: float = 0.025
## Siła organicznego zniekształcenia krawędzi (0.20 = 20% odchylenia od koła).
@export_range(0.0, 0.5, 0.01) var noise_amplitude: float = 0.20
## Szybkość płynięcia/falowania krawędzi po rozlaniu (0.0 = naturalna, statyczna kałuża w jednym miejscu).
@export_range(0.0, 20.0, 0.1) var noise_speed: float = 0.0
## Liczba wierzchołków krawędzi strefy (48–72 daje gładki kształt przy niskim koszcie CPU).
@export_range(16, 128, 4) var polygon_resolution: int = 64
## Liczba iteracji wygładzania krawędzi (Moving Average).
@export_range(0, 4, 1) var smoothing_iterations: int = 2
## Szybkość pulsowania (oddychania) rozlanej strefy (0.0 = wyłączone, brak powiększania i zmniejszania).
@export_range(0.0, 10.0, 0.2) var zone_pulse_speed: float = 0.0
## Amplituda pulsowania promienia strefy (0.0 = wyłączone, plama leży spokojnie w jednym miejscu).
@export_range(0.0, 0.15, 0.01) var zone_pulse_strength: float = 0.0
## Skala wewnętrznego, głębszego rdzenia cieczy (0.0 wyłącza wielowarstwowe cieniowanie środka).
@export_range(0.0, 1.0, 0.05) var visual_core_scale: float = 0.68
## Czas (w sekundach), w jakim ciecz rozlewa się po rozbiciu pocisku.
@export_range(0.1, 3.0, 0.1) var zone_spill_time: float = 0.4
## Czas zanikania przezroczystości pod koniec życia strefy (w sekundach).
@export_range(0.1, 5.0, 0.1) var zone_fade_time: float = 1.6
## Grubość subtelnego, ciemnego obrysu krawędzi (0.0 = miękka krawędź cieczy bez konturu).
@export_range(0.0, 8.0, 0.5) var zone_outline_thickness: float = 0.0
## Czy rysować animowane bąbelki / punkty energii pękające na powierzchni strefy?
@export var show_surface_bubbles: bool = true
## Liczba równoczesnych bąbelków animowanych na powierzchni strefy.
@export_range(0, 24, 1) var surface_bubble_count: int = 12

func _init() -> void:
	ability_name = "Rzut Strefą"
	cooldown = 10.0
	min_range = 0.0
	max_range = DEFAULT_THROW_MAX_RANGE
	damage_category = Effect.EffectCategory.POISON_ACID

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

	# =========================================================
	# FAZA 1: TELEGRAFOWANIE (PRZYGOTOWANIE RZUTU)
	# =========================================================
	var aim_direction: Vector2 = attacker.global_position.direction_to(target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT

	if can_entity_rotate(attacker):
		var rot_tween: Tween = attacker.create_tracked_tween()
		rot_tween.tween_property(attacker, "rotation", aim_direction.angle(), telegraph_time * TELEGRAPH_ROTATION_TIME_RATIO)
	else:
		orient_towards(attacker, aim_direction)

	if is_instance_valid(sprite) and not attacker.is_frozen:
		var visual_tween: Tween = attacker.create_tracked_tween()
		visual_tween.tween_property(
			sprite,
			"self_modulate",
			orig_modulate.lerp(zone_color, TELEGRAPH_TINT_WEIGHT),
			telegraph_time
		).set_trans(Tween.TRANS_SINE)

	var scene_tree: SceneTree = attacker.get_tree()
	if scene_tree == null:
		_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate)
		return

	await scene_tree.create_timer(telegraph_time).timeout

	_restore_sprite_modulate(attacker_ref, sprite_ref, orig_modulate)

	var live_attacker: Variant = attacker_ref.get_ref()
	var live_target: Variant = target_ref.get_ref()
	if not is_caster_active(live_attacker) or not is_instance_valid(live_target) or not (live_target is Node2D):
		_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate)
		return

	# =========================================================
	# FAZA 2: WYZNACZENIE TRAJEKTORII I WYSTRZELENIE POCISKU STREFY
	# =========================================================
	var caster: CharacterEntity = live_attacker as CharacterEntity
	var tgt: Node2D = live_target as Node2D
	var start_pos: Vector2 = caster.global_position
	var predicted_pos: Vector2 = tgt.global_position
	if "velocity" in tgt and tgt.velocity != Vector2.ZERO:
		predicted_pos += tgt.velocity * prediction_factor

	if start_pos.distance_to(predicted_pos) > max_range:
		predicted_pos = start_pos + (start_pos.direction_to(predicted_pos) * max_range)

	orient_towards(caster, start_pos.direction_to(predicted_pos))
	caster.play_throw_attack_animation(predicted_pos)

	var space_state: PhysicsDirectSpaceState2D = caster.get_world_2d().direct_space_state
	var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start_pos, predicted_pos)
	ray_query.collision_mask = obstacles_mask
	ray_query.exclude = [caster.get_rid()]
	var ray_result: Dictionary = space_state.intersect_ray(ray_query)
	var final_target_pos: Vector2 = ray_result["position"] if not ray_result.is_empty() else predicted_pos

	# Budujemy gotowe paczki efektów z aktualnych statystyk rzucającego przed startem lotu
	var impact_effects: Array[Effect] = build_hit_effects(caster)
	var zone_effects: Array[Effect] = build_effects_for_attack(
		caster,
		zone_tick_attack_data,
		zone_tick_damage_category,
		zone_tick_effects
	)

	var config := {
		"start_pos": start_pos,
		"target_pos": final_target_pos,
		"flight_time": flight_time,
		"color": zone_color,
		"projectile_radius": projectile_radius,
		"zone_radius": zone_radius,
		"zone_lifetime": zone_lifetime,
		"tick_rate": zone_tick_rate,
		"target_mode": target_mode,
		"include_caster": include_caster,
		"obstacles_mask": obstacles_mask,
		"noise_frequency": noise_frequency,
		"noise_amplitude": noise_amplitude,
		"noise_speed": noise_speed,
		"polygon_resolution": polygon_resolution,
		"smoothing_iterations": smoothing_iterations,
		"pulse_speed": zone_pulse_speed,
		"pulse_strength": zone_pulse_strength,
		"core_scale": visual_core_scale,
		"spill_time": zone_spill_time,
		"fade_time": zone_fade_time,
		"outline_thickness": zone_outline_thickness,
		"show_bubbles": show_surface_bubbles,
		"bubble_count": surface_bubble_count,
		"z_index": zone_z_index
	}

	var zone_node := ThrownZoneNode.new()
	zone_node.setup(
		caster,
		config,
		impact_effects,
		zone_effects,
		func(origin_pos: Vector2, rad: float) -> void:
			notify_components_area_detonated(attacker_ref.get_ref(), origin_pos, rad),
		func(hit_target: Node2D, origin_pos: Vector2) -> void:
			notify_components_target_hit(attacker_ref.get_ref(), hit_target, origin_pos)
	)
	spawn_ability_node(caster, zone_node, start_pos)

	_finish_cast(attacker_ref, combat_ctrl_ref, sprite_ref, orig_modulate)

func _restore_sprite_modulate(attacker_ref: WeakRef, sprite_ref: WeakRef, orig_modulate: Color) -> void:
	if sprite_ref == null:
		return
	var live_sprite: Variant = sprite_ref.get_ref()
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	if is_instance_valid(live_sprite) and live_sprite is CanvasItem:
		if not (is_caster_active(live_attacker) and (live_attacker as CharacterEntity).is_frozen):
			(live_sprite as CanvasItem).self_modulate = orig_modulate

func _finish_cast(
	attacker_ref: WeakRef,
	combat_ctrl_ref: WeakRef,
	sprite_ref: WeakRef,
	orig_modulate: Color
) -> void:
	_restore_sprite_modulate(attacker_ref, sprite_ref, orig_modulate)
	if combat_ctrl_ref != null:
		var live_ctrl: Variant = combat_ctrl_ref.get_ref()
		if is_instance_valid(live_ctrl) and live_ctrl is AICombatController:
			(live_ctrl as AICombatController).is_casting_ability = false
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	notify_components_cast_finished(live_attacker)

# ==============================================================================
# KLASA WEWNĘTRZNA: Lot pocisku, buforowane raycasty ścian, naturalna ciecz i bąbelki
# ==============================================================================
class ThrownZoneNode extends Node2D:
	const MIN_TIME_SEC: float = 0.01
	const ARC_HEIGHT_SCALE_BONUS: float = 0.80
	const SHADOW_ALPHA_MAX: float = 0.32
	const WALL_INSET_PX: float = 2.0
	const NOISE_SAMPLE_RADIUS: float = 50.0
	const IMPACT_SPARK_COUNT: int = 10

	## Naturalne 3-warstwowe przyciemnienie cieczy (eliminuje plastikowy, jaskrawy obrys).
	const OUTER_DARKEN_AMOUNT: float = 0.38
	const OUTER_FILL_ALPHA_MULT: float = 0.38
	const MID_LAYER_BLEND_RATIO: float = 0.48
	const MID_DARKEN_AMOUNT: float = 0.18
	const MID_FILL_ALPHA_MULT: float = 0.44
	const CORE_DARKEN_AMOUNT: float = 0.08
	const CORE_FILL_ALPHA_MULT: float = 0.56
	const BORDER_DARKEN_AMOUNT: float = 0.52
	const BORDER_ALPHA_MULT: float = 0.42

	const BUBBLE_MIN_RADIUS_PX: float = 2.5
	const BUBBLE_MAX_RADIUS_PX: float = 7.0
	const BUBBLE_CYCLE_SPEED_MIN: float = 0.70
	const BUBBLE_CYCLE_SPEED_MAX: float = 1.50
	const BUBBLE_HIGHLIGHT_LIGHTEN: float = 0.38
	const BUBBLE_RIM_DARKEN: float = 0.25

	var _attacker_ref: WeakRef = null
	var _attacker_faction_name: StringName = &""
	var _cfg: Dictionary = {}
	var _impact_effects: Array[Effect] = []
	var _zone_effects: Array[Effect] = []
	var _on_detonated: Callable = Callable()
	var _on_target_hit: Callable = Callable()

	var _elapsed: float = 0.0
	var _is_zone_active: bool = false
	var _is_polygon_settled: bool = false
	var _tick_timer: float = 0.0
	var _noise: FastNoiseLite = null

	## Bufor maksymalnych dystansów do ścian obliczany JEDNORAZOWO w chwili rozbicia pocisku (0 raycastów na klatkę!).
	var _cached_wall_limits: PackedFloat32Array = PackedFloat32Array()
	var _outer_polygon: PackedVector2Array = PackedVector2Array()
	var _mid_polygon: PackedVector2Array = PackedVector2Array()
	var _inner_polygon: PackedVector2Array = PackedVector2Array()
	var _bubbles: Array[Dictionary] = []

	func setup(
		attacker: CharacterEntity,
		config: Dictionary,
		impact_effects: Array[Effect],
		zone_effects: Array[Effect],
		on_detonated_cb: Callable,
		on_target_hit_cb: Callable
	) -> void:
		_attacker_ref = weakref(attacker) if is_instance_valid(attacker) else null
		if is_instance_valid(attacker):
			var faction: FactionComponent = attacker.get_node_or_null("FactionComponent") as FactionComponent
			if faction != null:
				_attacker_faction_name = faction.faction_name

		_cfg = config
		_impact_effects = impact_effects
		_zone_effects = zone_effects
		_on_detonated = on_detonated_cb
		_on_target_hit = on_target_hit_cb

		z_as_relative = false
		z_index = GameLayers.FX

		_noise = FastNoiseLite.new()
		_noise.seed = randi()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = 2
		_noise.frequency = float(_cfg["noise_frequency"])

		global_position = _cfg["start_pos"]

	func _process(delta: float) -> void:
		_elapsed += delta
		var flight_dur: float = maxf(MIN_TIME_SEC, float(_cfg["flight_time"]))

		if not _is_zone_active:
			var progress: float = clampf(_elapsed / flight_dur, 0.0, 1.0)
			global_position = (_cfg["start_pos"] as Vector2).lerp(_cfg["target_pos"] as Vector2, progress)
			queue_redraw()
			if progress >= 1.0:
				_detonate_and_spawn_zone()
		else:
			_tick_timer += delta
			var tick_rate: float = maxf(MIN_TIME_SEC, float(_cfg["tick_rate"]))
			if _tick_timer >= tick_rate:
				_tick_timer = 0.0
				_apply_zone_tick_effects()

			# Dla statycznej plamy po zakończeniu rozlewania nie przebudowujemy wielokąta (0 alokacji/klatkę!).
			if not _is_polygon_settled:
				_rebuild_organic_polygon()
			queue_redraw()

			if _elapsed >= flight_dur + float(_cfg["zone_lifetime"]):
				queue_free()

	## Rozbija pocisk, buforuje dystanse do ścian jednym przebiegiem raycastów i inicjalizuje bąbelki.
	func _detonate_and_spawn_zone() -> void:
		_is_zone_active = true
		_is_polygon_settled = false
		global_position = _cfg["target_pos"]
		z_index = int(_cfg["z_index"])

		var zone_rad: float = float(_cfg["zone_radius"])
		var proj_rad: float = float(_cfg["projectile_radius"])
		var base_col: Color = _cfg["color"]

		_cache_wall_distances(zone_rad)
		_init_surface_bubbles(zone_rad)
		_rebuild_organic_polygon()

		CombatVFXHelper.spawn_shockwave(self, global_position, proj_rad * 2.2, base_col)
		CombatVFXHelper.spawn_impact_sparks(self, global_position, Vector2.ZERO, base_col.lightened(0.25), IMPACT_SPARK_COUNT, proj_rad * 1.8)

		if _on_detonated.is_valid():
			_on_detonated.call(global_position, zone_rad)

		if not _impact_effects.is_empty():
			_apply_aoe_effects(proj_rad * ThrownZoneAbility.IMPACT_RADIUS_MULTIPLIER, _impact_effects, true)
		_apply_zone_tick_effects()

	## Jednorazowo mierzy dystans od środka strefy do najbliższych ścian dla każdego promienia wielokąta.
	func _cache_wall_distances(max_zone_radius: float) -> void:
		var poly_res: int = maxi(16, int(_cfg["polygon_resolution"]))
		var max_organic_reach: float = max_zone_radius * (1.0 + float(_cfg["noise_amplitude"]) + float(_cfg["pulse_strength"]))
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var o_mask: int = int(_cfg["obstacles_mask"])

		var excludes: Array[RID] = []
		var live_attacker: Variant = _attacker_ref.get_ref() if _attacker_ref != null else null
		if is_instance_valid(live_attacker) and live_attacker is CollisionObject2D:
			excludes.append((live_attacker as CollisionObject2D).get_rid())

		_cached_wall_limits.resize(poly_res)
		for i in range(poly_res):
			var angle: float = (float(i) / float(poly_res)) * TAU
			var dir := Vector2.from_angle(angle)
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + (dir * max_organic_reach)
			)
			query.collision_mask = o_mask
			query.exclude = excludes
			var res: Dictionary = space_state.intersect_ray(query)
			if not res.is_empty():
				var hit_pos: Vector2 = res["position"]
				_cached_wall_limits[i] = maxf(WALL_INSET_PX, global_position.distance_to(hit_pos) - WALL_INSET_PX)
			else:
				_cached_wall_limits[i] = max_organic_reach

	func _init_surface_bubbles(zone_rad: float) -> void:
		_bubbles.clear()
		if not bool(_cfg["show_bubbles"]):
			return
		var count: int = int(_cfg["bubble_count"])
		if count <= 0 or _cached_wall_limits.is_empty():
			return

		var poly_res: int = _cached_wall_limits.size()
		for _i in range(count):
			var idx: int = randi_range(0, poly_res - 1)
			var angle: float = (float(idx) / float(poly_res)) * TAU
			var max_dist: float = minf(zone_rad * 0.78, _cached_wall_limits[idx] * 0.78)
			var dist: float = sqrt(randf()) * max_dist
			_bubbles.append({
				"pos": Vector2.from_angle(angle) * dist,
				"phase": randf(),
				"speed": randf_range(BUBBLE_CYCLE_SPEED_MIN, BUBBLE_CYCLE_SPEED_MAX),
				"max_r": randf_range(BUBBLE_MIN_RADIUS_PX, BUBBLE_MAX_RADIUS_PX)
			})

	## Buduje 3 współśrodkowe wielokąty cieczy na podstawie buforowanych granic ścian — ZERO raycastów w _process()!
	func _rebuild_organic_polygon() -> void:
		var poly_res: int = _cached_wall_limits.size()
		if poly_res < 3:
			return

		var flight_dur: float = float(_cfg["flight_time"])
		var zone_elapsed: float = maxf(0.0, _elapsed - flight_dur)
		var spill_time: float = float(_cfg["spill_time"])
		var is_spilling: bool = spill_time > 0.0 and zone_elapsed < spill_time
		var size_mult: float = lerpf(0.12, 1.0, clampf(zone_elapsed / maxf(MIN_TIME_SEC, spill_time), 0.0, 1.0)) if is_spilling else 1.0

		var base_rad: float = float(_cfg["zone_radius"]) * size_mult
		var pulse_strength: float = float(_cfg["pulse_strength"])
		var pulse_speed: float = float(_cfg["pulse_speed"])
		var pulse_wave: float = (
			sin(zone_elapsed * pulse_speed) * (base_rad * pulse_strength)
			if pulse_strength > 0.0 and pulse_speed > 0.0
			else 0.0
		)
		var current_radius: float = base_rad + pulse_wave
		var n_amp: float = float(_cfg["noise_amplitude"])
		var n_spd: float = float(_cfg["noise_speed"])
		var n_z: float = zone_elapsed * n_spd
		var core_scale: float = float(_cfg["core_scale"])

		var raw_outer := PackedVector2Array()
		raw_outer.resize(poly_res)
		for i in range(poly_res):
			var angle: float = (float(i) / float(poly_res)) * TAU
			var noise_val: float = _noise.get_noise_3d(cos(angle) * NOISE_SAMPLE_RADIUS, sin(angle) * NOISE_SAMPLE_RADIUS, n_z)
			var desired_rad: float = current_radius * (1.0 + (noise_val * n_amp))
			var clamped_rad: float = minf(desired_rad, _cached_wall_limits[i])
			raw_outer[i] = Vector2.from_angle(angle) * clamped_rad

		var smooth_iter: int = int(_cfg["smoothing_iterations"])
		for _it in range(smooth_iter):
			var smoothed := PackedVector2Array()
			smoothed.resize(poly_res)
			for i in range(poly_res):
				var prev: Vector2 = raw_outer[(i - 1 + poly_res) % poly_res]
				var curr: Vector2 = raw_outer[i]
				var next: Vector2 = raw_outer[(i + 1) % poly_res]
				smoothed[i] = (prev + (curr * 2.0) + next) * 0.25
			raw_outer = smoothed

		_outer_polygon = raw_outer
		_mid_polygon = PackedVector2Array()
		_inner_polygon = PackedVector2Array()
		if core_scale > 0.0:
			var mid_scale: float = lerpf(1.0, core_scale, MID_LAYER_BLEND_RATIO)
			_mid_polygon.resize(poly_res)
			_inner_polygon.resize(poly_res)
			for i in range(poly_res):
				_mid_polygon[i] = _outer_polygon[i] * mid_scale
				_inner_polygon[i] = _outer_polygon[i] * core_scale

		# Jeśli rozlewanie się zakończyło i nie ma animacji falowania/pulsowania, zamrażamy kształt w jednym miejscu.
		if not is_spilling and n_spd <= 0.0 and (pulse_strength <= 0.0 or pulse_speed <= 0.0):
			_is_polygon_settled = true

	func _draw() -> void:
		var base_col: Color = _cfg["color"]
		var flight_dur: float = maxf(MIN_TIME_SEC, float(_cfg["flight_time"]))

		if not _is_zone_active:
			var progress: float = clampf(_elapsed / flight_dur, 0.0, 1.0)
			var arc_scale: float = 1.0 + (sin(progress * PI) * ARC_HEIGHT_SCALE_BONUS)
			var draw_rad: float = float(_cfg["projectile_radius"]) * arc_scale
			var target_local: Vector2 = (_cfg["target_pos"] as Vector2) - global_position

			draw_circle(target_local, draw_rad * 0.85, Color(0.0, 0.0, 0.0, SHADOW_ALPHA_MAX * (1.0 - progress)))
			draw_arc(target_local, float(_cfg["projectile_radius"]) * 1.4, 0.0, TAU, 24, Color(base_col.r, base_col.g, base_col.b, 0.45 * progress), 2.0, true)
			draw_circle(Vector2.ZERO, draw_rad * 1.25, Color(base_col.r, base_col.g, base_col.b, 0.30))
			draw_circle(Vector2.ZERO, draw_rad, base_col)
			draw_circle(Vector2.ZERO, draw_rad * 0.45, base_col.lightened(0.35))
			return

		var zone_elapsed: float = maxf(0.0, _elapsed - flight_dur)
		var time_left: float = float(_cfg["zone_lifetime"]) - zone_elapsed
		var fade_time: float = float(_cfg["fade_time"])
		var alpha_mult: float = 1.0
		if fade_time > 0.0 and time_left < fade_time:
			alpha_mult = clampf(time_left / fade_time, 0.0, 1.0)

		# 3-warstwowa głębia rozlanej cieczy (ciemniejsza krawędź -> półprzezroczysty środek -> głębsze dno)
		if _outer_polygon.size() >= 3:
			var outer_tint: Color = base_col.darkened(OUTER_DARKEN_AMOUNT)
			outer_tint.a = base_col.a * OUTER_FILL_ALPHA_MULT * alpha_mult
			draw_colored_polygon(_outer_polygon, outer_tint)

			if _mid_polygon.size() >= 3:
				var mid_tint: Color = base_col.darkened(MID_DARKEN_AMOUNT)
				mid_tint.a = base_col.a * MID_FILL_ALPHA_MULT * alpha_mult
				draw_colored_polygon(_mid_polygon, mid_tint)

			if _inner_polygon.size() >= 3:
				var core_tint: Color = base_col.darkened(CORE_DARKEN_AMOUNT)
				core_tint.a = base_col.a * CORE_FILL_ALPHA_MULT * alpha_mult
				draw_colored_polygon(_inner_polygon, core_tint)

			var outline_thick: float = float(_cfg["outline_thickness"])
			if outline_thick > 0.0:
				var outline: PackedVector2Array = _outer_polygon.duplicate()
				outline.append(outline[0])
				var border_col: Color = base_col.darkened(BORDER_DARKEN_AMOUNT)
				border_col.a = base_col.a * BORDER_ALPHA_MULT * alpha_mult
				draw_polyline(outline, border_col, outline_thick, true)

		# Animowane bąbelki na powierzchni cieczy
		if not _bubbles.is_empty():
			var spill_time: float = float(_cfg["spill_time"])
			var spill_ratio: float = clampf(zone_elapsed / maxf(MIN_TIME_SEC, spill_time), 0.0, 1.0)
			var bubble_rim: Color = base_col.darkened(BUBBLE_RIM_DARKEN)
			var bubble_glint: Color = base_col.lightened(BUBBLE_HIGHLIGHT_LIGHTEN)
			for b in _bubbles:
				var cycle: float = fmod(float(b["phase"]) + (zone_elapsed * float(b["speed"])), 1.0)
				var b_pos: Vector2 = (b["pos"] as Vector2) * spill_ratio
				var b_rad: float = float(b["max_r"]) * lerpf(0.25, 1.0, cycle)
				var b_alpha: float = sin(cycle * PI) * alpha_mult
				draw_circle(b_pos, b_rad, Color(bubble_rim.r, bubble_rim.g, bubble_rim.b, 0.28 * b_alpha))
				draw_arc(b_pos, b_rad, 0.0, TAU, 14, Color(bubble_glint.r, bubble_glint.g, bubble_glint.b, 0.72 * b_alpha), 1.4, true)

	func _apply_zone_tick_effects() -> void:
		if _zone_effects.is_empty():
			return
		_apply_aoe_effects(float(_cfg["zone_radius"]), _zone_effects, false)

	func _apply_aoe_effects(radius_to_check: float, effects_to_apply: Array[Effect], notify_hit_components: bool) -> void:
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var shape := CircleShape2D.new()
		shape.radius = radius_to_check
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, global_position)

		var live_attacker: Variant = _attacker_ref.get_ref() if _attacker_ref != null else null
		var mode: int = int(_cfg["target_mode"])
		var allow_allies: bool = (mode == ThrownZoneAbility.ZoneTargetMode.ALLIES_ONLY or mode == ThrownZoneAbility.ZoneTargetMode.EVERYONE)
		var allow_enemies: bool = (mode == ThrownZoneAbility.ZoneTargetMode.ENEMIES_ONLY or mode == ThrownZoneAbility.ZoneTargetMode.EVERYONE)
		var allow_self: bool = bool(_cfg["include_caster"])
		var o_mask: int = int(_cfg["obstacles_mask"])

		var hits: Array[Dictionary] = space_state.intersect_shape(query, ThrownZoneAbility.MAX_ZONE_TARGETS)
		for hit in hits:
			var col: Node2D = hit["collider"] as Node2D
			if not AIAbility.can_affect_target(live_attacker, col, allow_allies, allow_enemies, allow_self, _attacker_faction_name):
				continue

			# Weryfikacja linii wzroku, aby kałuża nie przenikała przez grubą ścianę
			var los_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, col.global_position)
			los_query.collision_mask = o_mask
			var excludes: Array[RID] = []
			if col is CollisionObject2D:
				excludes.append((col as CollisionObject2D).get_rid())
			if is_instance_valid(live_attacker) and live_attacker is CollisionObject2D:
				excludes.append((live_attacker as CollisionObject2D).get_rid())
			los_query.exclude = excludes

			var los_result: Dictionary = space_state.intersect_ray(los_query)
			if not los_result.is_empty() and los_result["collider"] != col:
				continue

			AIAbility.apply_effects_to_target(live_attacker, col, effects_to_apply, global_position)
			if notify_hit_components and _on_target_hit.is_valid():
				_on_target_hit.call(col, global_position)
