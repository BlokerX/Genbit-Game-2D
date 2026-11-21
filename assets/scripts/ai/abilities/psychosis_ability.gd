extends AIAbility
class_name PsychosisAbility
## Uniwersalny archetyp koncentrycznej fali obszarowej (SOLID - OCP / DRY).
## Wszystkie obrażenia, ogłuszenie, odrzut i statusy (np. Freeze, Slow, Poison, ArmorDebuff) konfiguruje się
## w jednym miejscu w pliku .tres przez AttackData i on_hit_effects — bez sztywnych flag w kodzie.

#region Stałe Domenowe (Brak magicznych liczb)
const MAX_WAVE_HITS: int = 32
const HALF_CAST_FACTOR: float = 0.5
const DEFAULT_WAVE_MAX_RANGE: float = 700.0
const DEFAULT_OVERLAY_LAYER: int = GameLayers.UI_HUD - 5
#endregion

@export_category("Archetyp: Koncentryczna Fala Obszarowa")

@export_group("Zasięg i Czas Ładowania")
## Czas ładowania fali przed uderzeniem (w sekundach).
@export_range(0.1, 5.0, 0.1) var cast_time: float = 1.2
## Promień uderzenia fali obszarowej (w pikselach).
@export_range(50.0, 1500.0, 10.0) var blast_radius: float = 450.0
## Czy fala ma oddziaływać również na sojuszników rzucającego?
@export var friendly_fire: bool = false

@export_group("Wizualizacje Fali (VFX)")
## Główny kolor pierścieni i aury fali (np. fiolet psychozy, błękit mrozu, złoto szoku).
@export var aura_color: Color = Color(0.45, 0.08, 0.88, 0.72)
## Liczba przesuniętych w fazie koncentrycznych pierścieni rysowanych podczas ładowania i eksplozji.
@export_range(1, 5, 1) var wave_ring_count: int = 3
## Mnożnik chwilowego pulsowania skali rzucającego w trakcie ładowania fali.
@export_range(1.0, 2.5, 0.05) var visual_scale_pulse: float = 1.25
## Czas rozchodzenia się i zanikania fali po wybuchu (w sekundach).
@export_range(0.1, 2.0, 0.05) var explosion_fade_time: float = 0.8
## Warstwa renderowania (Z-Index) fali na mapie (domyślnie nad podłogą / pod postaciami).
@export var wave_z_index: int = GameLayers.FLOOR_HAZARD + 5

@export_group("Specjalne Oddziaływania Fali")
## Czy fala ma czyścić pamięć celu (amnezja) u trafionych jednostek AI, cofając je do stanu Idle?
@export var apply_npc_amnesia: bool = true
## Siła wstrząsu kamery gracza w przypadku trafienia falą (0.0 wyłącza wstrząs).
@export_range(0.0, 2.0, 0.05) var camera_trauma_amount: float = 0.85

@export_group("Efekt Ekranowy / Winieta (Tylko Gracz)")
## Czy trafienie gracza falą ma wywołać atmosferyczną winietę / mgłę ekranową?
@export var apply_screen_overlay: bool = true
## Kolor winiety lub zaciemnienia ekranu po trafieniu falą.
@export var overlay_color: Color = Color(0.05, 0.0, 0.12, 0.92)
## Czas trwania efektu ekranowego (w sekundach).
@export_range(0.5, 15.0, 0.5) var overlay_duration: float = 5.0
## Promień bardziej przejrzystego środka winiety (0.0 = niemal pełne zaciemnienie, 0.35 = wyraźna ramka mgły).
@export_range(0.0, 0.65, 0.02) var overlay_inner_clear_radius: float = 0.18
## Warstwa CanvasLayer dla winiety (domyślnie tuż pod UI_HUD, aby zachować czytelność interfejsu gracza).
@export var overlay_canvas_layer: int = DEFAULT_OVERLAY_LAYER

func _init() -> void:
	ability_name = "Fala Psychozy"
	cooldown = 18.0
	min_range = 0.0
	max_range = DEFAULT_WAVE_MAX_RANGE
	damage_category = Effect.EffectCategory.MENTAL_PSYCHOSIS

func execute(attacker: CharacterEntity, _target: CharacterEntity) -> void:
	if not is_instance_valid(attacker):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# 1. Tworzenie wielopierścieniowej wizualizacji fali wokół atakującego
	var wave_visual := PsychosisWaveVisual.new()
	wave_visual.setup(attacker, blast_radius, aura_color, cast_time, explosion_fade_time, wave_ring_count, wave_z_index)
	spawn_ability_node(attacker, wave_visual, attacker.global_position)

	# Pulsowanie skali w oparciu o bezpieczne base_scale
	var tween: Tween = attacker.create_tracked_tween()
	var orig_scale: Vector2 = attacker.base_scale
	tween.tween_property(attacker, "scale", orig_scale * visual_scale_pulse, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)
	tween.tween_property(attacker, "scale", orig_scale, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		_cleanup_cast(attacker, combat_ctrl, wave_visual, true)
		return

	# 2. Faza ładowania fali
	await attacker.get_tree().create_timer(cast_time).timeout

	if is_instance_valid(attacker):
		attacker.reset_visual_scale()

	if not is_instance_valid(attacker) or not attacker.is_inside_tree() or attacker.is_dead:
		_cleanup_cast(attacker, combat_ctrl, wave_visual, true)
		return

	# 3. Uderzenie fali i aplikacja efektów z jednolitego kontraktu AIAbility
	if is_instance_valid(wave_visual):
		wave_visual.explode()
	CombatVFXHelper.spawn_shockwave(attacker, attacker.global_position, blast_radius, aura_color)

	var hits: Array[Dictionary] = _query_targets_in_radius(attacker)
	var hit_effects: Array[Effect] = build_hit_effects(attacker)
	var hit_player: bool = false

	for hit in hits:
		var col: Node2D = hit["collider"] as Node2D
		if not can_affect_target(attacker, col, friendly_fire, true, false):
			continue

		if col.is_in_group("Player"):
			hit_player = true

		apply_effects_to_target(attacker, col, hit_effects, attacker.global_position)

		if apply_npc_amnesia:
			_apply_amnesia_to_npc(col)

	# 4. Oprawa ekranowa i wstrząs kamery (wyłącznie po trafieniu gracza)
	if hit_player:
		if camera_trauma_amount > 0.0:
			trigger_camera_shake(attacker, camera_trauma_amount)
		if apply_screen_overlay:
			_spawn_screen_overlay(attacker)

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

func _apply_amnesia_to_npc(target_node: Node2D) -> void:
	if not is_instance_valid(target_node) or not target_node.has_node("AIController"):
		return
	var target_ai: Node = target_node.get_node("AIController")
	if target_ai != null and target_ai.get("blackboard") != null:
		target_ai.blackboard.target = null
		target_ai.blackboard.has_last_known_position = false
		target_ai.blackboard.want_to_move = false
		if target_ai.get("state_machine") != null:
			target_ai.state_machine.change_state("Idle")

func _spawn_screen_overlay(attacker: CharacterEntity) -> void:
	var tree: SceneTree = attacker.get_tree()
	if tree == null:
		return
	var host: Node = tree.get_first_node_in_group("Map")
	if not is_instance_valid(host):
		host = tree.current_scene
	if not is_instance_valid(host):
		return

	var overlay := ScreenOverlayVFX.new()
	overlay.setup(overlay_duration, overlay_color, overlay_inner_clear_radius, overlay_canvas_layer)
	host.add_child(overlay)

func _cleanup_cast(
	attacker: CharacterEntity,
	combat_ctrl: AICombatController,
	wave_visual: PsychosisWaveVisual,
	destroy_visual: bool
) -> void:
	if is_instance_valid(attacker):
		attacker.reset_visual_scale()
	if destroy_visual and is_instance_valid(wave_visual):
		wave_visual.queue_free()
	if is_instance_valid(combat_ctrl):
		combat_ctrl.is_casting_ability = false

# ==============================================================================
# KLASY WEWNĘTRZNE: Wielopierścieniowa fala i shaderowa winieta ekranowa
# ==============================================================================
class PsychosisWaveVisual extends Node2D:
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
		# Stała linia zewnętrznej granicy pozwala graczowi ocenić bezpieczny dystans
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

## Shaderowa winieta / mgła ekranowa z płynnym pulsowaniem i wygaszaniem (SRP).
class ScreenOverlayVFX extends CanvasLayer:
	const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 overlay_color : source_color = vec4(0.05, 0.0, 0.12, 0.92);
uniform float intensity = 0.0;
uniform float inner_clear_radius = 0.18;
uniform float outer_solid_radius = 0.78;
void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5)) * 1.41421356;
	float vignette = smoothstep(inner_clear_radius, outer_solid_radius, dist);
	float alpha = mix(overlay_color.a * 0.48, overlay_color.a, vignette) * intensity;
	COLOR = vec4(overlay_color.rgb, clamp(alpha, 0.0, 1.0));
}
"""
	const FADE_IN_SEC: float = 0.12
	const PULSE_HALF_SEC: float = 0.30
	const MIN_FADE_OUT_SEC: float = 0.15
	const OUTER_SOLID_OFFSET: float = 0.58

	var _duration: float = 5.0
	var _color: Color = Color(0.05, 0.0, 0.12, 0.92)
	var _inner_clear: float = 0.18
	var _target_layer: int = DEFAULT_OVERLAY_LAYER

	func setup(duration: float, color: Color, inner_clear_radius: float, target_layer: int) -> void:
		_duration = duration
		_color = color
		_inner_clear = clampf(inner_clear_radius, 0.0, 0.65)
		_target_layer = target_layer

	func _ready() -> void:
		layer = _target_layer
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var shader := Shader.new()
		shader.code = VIGNETTE_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("overlay_color", _color)
		mat.set_shader_parameter("intensity", 0.0)
		mat.set_shader_parameter("inner_clear_radius", _inner_clear)
		mat.set_shader_parameter("outer_solid_radius", minf(1.0, _inner_clear + OUTER_SOLID_OFFSET))
		rect.material = mat
		add_child(rect)

		var fade_out_sec: float = maxf(MIN_FADE_OUT_SEC, _duration - (FADE_IN_SEC + PULSE_HALF_SEC * 2.0))
		var tween: Tween = create_tween()
		tween.tween_property(mat, "shader_parameter/intensity", 1.0, FADE_IN_SEC)
		tween.tween_property(mat, "shader_parameter/intensity", 0.78, PULSE_HALF_SEC).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/intensity", 0.96, PULSE_HALF_SEC).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/intensity", 0.0, fade_out_sec).set_trans(Tween.TRANS_SINE)
		await tween.finished
		queue_free()
