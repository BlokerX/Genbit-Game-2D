extends Area2D
class_name TelegraphedAOE
## Obszar ostrzegawczy (AOE) rysowany na ziemi przed wybuchem umiejętności specjalnej AI.
## Posiada wyraźną granicę rażenia, narastający impuls ostrzegawczy, falę uderzeniową przy detonacji,
## automatyczne anulowanie po śmierci rzucającego (cancel_on_caster_death) oraz callbacki AbilityComponent.

#region Stałe Wizualne i Fizyczne (Brak magicznych liczb)
const BACKGROUND_ALPHA_MULTIPLIER: float = 0.32
const INNER_FILL_ALPHA_MULTIPLIER: float = 0.72
const INNER_EDGE_LIGHTEN: float = 0.35
const OUTER_RING_POINTS: int = 48
const OUTER_RING_MIN_ALPHA: float = 0.55
const OUTER_RING_MAX_ALPHA: float = 0.98
const OUTER_RING_PULSE_SPEED_RAD: float = 18.0
const WARNING_PULSE_PROGRESS_THRESHOLD: float = 0.72
const CENTER_MARKER_RADIUS_PX: float = 4.5
const CENTER_MARKER_ALPHA: float = 0.75
const MIN_DURATION_SEC: float = 0.01
const DEFAULT_TARGET_RADIUS: float = 20.0
const ALL_LAYERS_MASK: int = 0xFFFFFFFF
#endregion

var radius: float = 50.0
var duration: float = 1.0
var elapsed: float = 0.0
var effects: Array[Effect] = []
var source_entity: Node2D = null
var _source_ref: WeakRef = null
var _had_source_entity: bool = false
var _source_faction_name: StringName = &""
var specific_target: Node2D = null # Opcjonalny, pojedynczy cel
var _specific_target_ref: WeakRef = null
## Opcjonalny callback wywoływany w chwili detonacji: func(origin_pos: Vector2, rad: float) -> void.
var on_detonated_callback: Callable = Callable()
## Opcjonalny callback wywoływany dla każdego trafionego celu: func(target: Node2D, origin_pos: Vector2) -> void.
var on_target_hit_callback: Callable = Callable()

@export_group("Zasady i Wygląd Strefy")
## Czy wybuch strefy ma ranić również sojuszników oraz samego rzucającego?
@export var friendly_fire: bool = false
## Jeśli true (domyślnie), śmierć lub usunięcie rzucającego przed końcem odliczania natychmiast anuluje strefę bez wybuchu.
## Ustaw false wyłącznie dla niezależnych pocisków/opadających plam, które mają dokończyć lot po śmierci sprawcy.
@export var cancel_on_caster_death: bool = true
## Główny kolor strefy zagrożenia (wypełnienia i obramowania).
@export var danger_color: Color = Color(1.0, 0.0, 0.0, 0.5)
## Grubość zewnętrznej obwódki wyznaczającej dokładną granicę rażenia (w pikselach).
@export_range(1.0, 8.0, 0.5) var outline_width_px: float = 2.5
## Czy wyświetlać wyraźny pierścień zewnętrzny i znacznik środka strefy?
@export var show_outer_ring: bool = true
## Czy w momencie detonacji wygenerować proceduralną falę uderzeniową (CombatVFXHelper)?
@export var spawn_detonation_vfx: bool = true

## Inicjalizuje parametry strefy ostrzegawczej, zapamiętując frakcję i WeakRef sprawcy.
func setup(pos: Vector2, rad: float, dur: float, effs: Array[Effect], source: Node2D, target: Node2D = null) -> void:
	global_position = pos
	radius = rad
	duration = dur
	effects = effs

	_had_source_entity = is_instance_valid(source)
	source_entity = source if _had_source_entity else null
	_source_ref = weakref(source_entity) if _had_source_entity else null

	specific_target = target if is_instance_valid(target) else null
	_specific_target_ref = weakref(specific_target) if specific_target != null else null

	if _had_source_entity:
		var fac: FactionComponent = source_entity.get_node_or_null("FactionComponent") as FactionComponent
		if fac != null:
			_source_faction_name = fac.faction_name

func _ready() -> void:
	# Konfigurujemy kolizje tylko wtedy, gdy nie mamy konkretnego celu (prawdziwe AOE)
	if specific_target == null:
		collision_layer = 0
		collision_mask = ALL_LAYERS_MASK

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		col.shape = circle
		add_child(col)

func _process(delta: float) -> void:
	var live_source: Node2D = _resolve_live_source()
	if _had_source_entity:
		if live_source == null:
			if cancel_on_caster_death:
				queue_free()
				return
		else:
			if cancel_on_caster_death and (live_source.get("is_dead") == true or not live_source.is_inside_tree()):
				queue_free()
				return
			if live_source.get("is_casting_interrupted") == true:
				queue_free()
				return

	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		_explode()

func _draw() -> void:
	var progress: float = clampf(elapsed / maxf(MIN_DURATION_SEC, duration), 0.0, 1.0)

	# 1. Półprzezroczyste tło pełnego zasięgu rażenia
	var bg_color: Color = danger_color
	bg_color.a = danger_color.a * BACKGROUND_ALPHA_MULTIPLIER
	draw_circle(Vector2.ZERO, radius, bg_color)

	# 2. Narastające wewnętrzne wypełnienie odliczające czas do wybuchu
	var inner_radius: float = radius * progress
	var fill_color: Color = danger_color
	fill_color.a = danger_color.a * INNER_FILL_ALPHA_MULTIPLIER
	draw_circle(Vector2.ZERO, inner_radius, fill_color)

	if inner_radius > 1.0:
		var inner_edge: Color = danger_color.lightened(INNER_EDGE_LIGHTEN)
		inner_edge.a = clampf(danger_color.a * 1.15, 0.35, 0.90)
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, OUTER_RING_POINTS, inner_edge, outline_width_px * 0.75, true)

	# 3. Wyraźna zewnętrzna krawędź (pulsuje szybciej tuż przed detonacją dla lepszego UX)
	if show_outer_ring:
		var pulse_wave: float = 0.0
		if progress >= WARNING_PULSE_PROGRESS_THRESHOLD:
			pulse_wave = (sin(elapsed * OUTER_RING_PULSE_SPEED_RAD) + 1.0) * 0.5
		var ring_alpha: float = lerpf(OUTER_RING_MIN_ALPHA, OUTER_RING_MAX_ALPHA, maxf(progress * 0.6, pulse_wave))
		var ring_color := Color(danger_color.r, danger_color.g, danger_color.b, ring_alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, OUTER_RING_POINTS, ring_color, outline_width_px, true)

		var center_col: Color = danger_color.lightened(INNER_EDGE_LIGHTEN)
		center_col.a = CENTER_MARKER_ALPHA
		draw_circle(Vector2.ZERO, CENTER_MARKER_RADIUS_PX, center_col)

func _explode() -> void:
	set_process(false)
	var live_source: Node2D = _resolve_live_source()
	if _had_source_entity and cancel_on_caster_death:
		if live_source == null or live_source.get("is_dead") == true:
			queue_free()
			return

	if spawn_detonation_vfx:
		CombatVFXHelper.spawn_shockwave(self, global_position, radius, danger_color)

	if on_detonated_callback.is_valid():
		on_detonated_callback.call(global_position, radius)

	if _specific_target_ref != null:
		var live_target: Node2D = _specific_target_ref.get_ref() as Node2D
		if is_instance_valid(live_target):
			var target_rad: float = CharacterEntity.get_effective_radius_of(live_target, DEFAULT_TARGET_RADIUS)
			var edge_dist: float = maxf(0.0, global_position.distance_to(live_target.global_position) - target_rad)
			if edge_dist <= radius:
				_apply_effects_to(live_target, live_source)
	else:
		for body in get_overlapping_bodies():
			if not is_instance_valid(body):
				continue
			if live_source != null and body == live_source and not friendly_fire:
				continue
			if not friendly_fire and _is_ally(body, live_source):
				continue
			_apply_effects_to(body, live_source)

	queue_free()

func _resolve_live_source() -> Node2D:
	if _source_ref == null:
		source_entity = null
		return null
	var candidate: Variant = _source_ref.get_ref()
	if is_instance_valid(candidate) and candidate is Node2D:
		source_entity = candidate as Node2D
		return source_entity
	source_entity = null
	return null

func _is_ally(body: Node2D, live_source: Node2D) -> bool:
	return FactionComponent.is_ally_of(live_source, body, _source_faction_name)

func _apply_effects_to(target_node: Node2D, live_source: Node2D) -> void:
	if not is_instance_valid(target_node) or not target_node.has_method("receive_effect"):
		return
	AIAbility.apply_effects_to_target(live_source, target_node, effects, global_position)
	if on_target_hit_callback.is_valid():
		on_target_hit_callback.call(target_node, global_position)
