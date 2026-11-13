extends Area2D
class_name TelegraphedAOE
## Obszar ostrzegawczy (AOE) rysowany na ziemi przed wybuchem umiejętności specjalnej AI.

const BACKGROUND_ALPHA_MULTIPLIER: float = 0.4
const DEFAULT_TARGET_RADIUS: float = 20.0
const ALL_LAYERS_MASK: int = 0xFFFFFFFF

var radius: float = 50.0
var duration: float = 1.0
var elapsed: float = 0.0
var effects: Array[Effect] = []
var source_entity: Node2D = null
var _source_faction_name: StringName = &""
var specific_target: Node2D = null # Opcjonalny, pojedynczy cel
@export var friendly_fire: bool = false
@export var danger_color: Color = Color(1.0, 0.0, 0.0, 0.5)

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

		var col: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
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
	# Tło rysujemy z nałożoną przezroczystością (40% bazowej wartości alpha)
	var bg_color: Color = danger_color
	bg_color.a = danger_color.a * BACKGROUND_ALPHA_MULTIPLIER
	draw_circle(Vector2.ZERO, radius, bg_color)

	# Rośnięcie wewnętrznego okręgu w pełnym kolorze
	var progress: float = clampf(elapsed / maxf(0.01, duration), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * progress, danger_color)

func _explode() -> void:
	set_process(false)
	if not is_instance_valid(source_entity):
		source_entity = null

	if specific_target != null:
		if is_instance_valid(specific_target):
			var target_rad: float = float(specific_target.get("combat_radius")) if "combat_radius" in specific_target else DEFAULT_TARGET_RADIUS
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
	if is_instance_valid(target_node) and target_node.has_method("receive_effect"):
		for eff in effects:
			if eff == null:
				continue
			var cloned_eff: Effect = eff.duplicate(true)
			cloned_eff.source_entity = source_entity if is_instance_valid(source_entity) else null
			cloned_eff.source_position = global_position
			target_node.receive_effect(cloned_eff)
