extends Area2D
class_name TelegraphedAOE
## Obszar ostrzegawczy (AOE) rysowany na ziemi przed wybuchem umiejętności specjalnej AI.
## Posiada wyraźną granicę rażenia, narastający impuls ostrzegawczy, falę uderzeniową przy detonacji
## oraz opcjonalne callbacki dla modularnych komponentów AbilityComponent (SOLID - OCP / DIP).

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
var _source_faction_name: StringName = &""
var specific_target: Node2D = null # Opcjonalny, pojedynczy cel
## Opcjonalny callback wywoływany w chwili detonacji: func(origin_pos: Vector2, rad: float) -> void.
var on_detonated_callback: Callable = Callable()
## Opcjonalny callback wywoływany dla każdego trafionego celu: func(target: Node2D, origin_pos: Vector2) -> void.
var on_target_hit_callback: Callable = Callable()

@export_group("Zasady i Wygląd Strefy")
## Czy wybuch strefy ma ranić również sojuszników oraz samego rzucającego?
@export var friendly_fire: bool = false
## Główny kolor strefy zagrożenia (wypełnienia i obramowania).
@export var danger_color: Color = Color(1.0, 0.0, 0.0, 0.5)
## Grubość zewnętrznej obwódki wyznaczającej dokładną granicę rażenia (w pikselach).
@export_range(1.0, 8.0, 0.5) var outline_width_px: float = 2.5
## Czy wyświetlać wyraźny pierścień zewnętrzny i znacznik środka strefy?
@export var show_outer_ring: bool = true
## Czy w momencie detonacji wygenerować proceduralną falę uderzeniową (CombatVFXHelper)?
@export var spawn_detonation_vfx: bool = true

## Inicjalizuje parametry strefy ostrzegawczej, zapamiętując frakcję sprawcy na wypadek jego śmierci przed wybuchem.
func setup(pos: Vector2, rad: float, dur: float, effs: Array[Effect], source: Node2D, target: Node2D = null) -> void:
	global_position = pos
	radius = rad
	duration = dur
	effects = effs
	source_entity = source if is_instance_valid(source) else null
	specific_target = target if is_instance_valid(target) else null
	if is_instance_valid(source_entity):
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
	# Oczyszczamy referencję, jeśli rzucający zginął przed wybuchem plamy (chroni przed błędem 'previously freed')
	if not is_instance_valid(source_entity):
		source_entity = null
	elif source_entity.get("is_casting_interrupted"):
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
	if not is_instance_valid(source_entity):
		source_entity = null

	if spawn_detonation_vfx:
		CombatVFXHelper.spawn_shockwave(self, global_position, radius, danger_color)

	if on_detonated_callback.is_valid():
		on_detonated_callback.call(global_position, radius)

	if specific_target != null:
		if is_instance_valid(specific_target):
			var target_rad: float = CharacterEntity.get_effective_radius_of(specific_target, DEFAULT_TARGET_RADIUS)
			var edge_dist: float = maxf(0.0, global_position.distance_to(specific_target.global_position) - target_rad)
			if edge_dist <= radius:
				_apply_effects_to(specific_target)
	else:
		for body in get_overlapping_bodies():
			if not is_instance_valid(body):
				continue
			if source_entity != null and body == source_entity and not friendly_fire:
				continue
			# Blokada AOE dla sojuszników
			if not friendly_fire and _is_ally(body):
				continue
			_apply_effects_to(body)

	queue_free()

func _is_ally(body: Node2D) -> bool:
	var valid_source: Node2D = source_entity if is_instance_valid(source_entity) else null
	return FactionComponent.is_ally_of(valid_source, body, _source_faction_name)

func _apply_effects_to(target_node: Node2D) -> void:
	AIAbility.apply_effects_to_target(source_entity, target_node, effects, global_position)
	if on_target_hit_callback.is_valid():
		on_target_hit_callback.call(target_node, global_position)
