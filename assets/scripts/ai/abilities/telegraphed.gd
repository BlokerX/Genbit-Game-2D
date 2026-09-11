extends Area2D
class_name TelegraphedAOE

var radius: float = 50.0
var duration: float = 1.0
var elapsed: float = 0.0
var effects: Array[Effect] = []
var source_entity: Node2D
var specific_target: Node2D = null # <--- Opcjonalny, pojedynczy cel

@export var friendly_fire: bool = false

func setup(pos: Vector2, rad: float, dur: float, effs: Array[Effect], source: Node2D, target: Node2D = null) -> void:
	global_position = pos
	radius = rad
	duration = dur
	effects = effs
	source_entity = source
	specific_target = target # Zapisujemy konkretną ofiarę

func _ready() -> void:
	# Konfigurujemy kolizje tylko wtedy, gdy nie mamy konkretnego celu (prawdziwe AOE)
	if specific_target == null:
		collision_layer = 0
		collision_mask = 0xFFFFFFFF
		var col = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = radius
		col.shape = circle
		add_child(col)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	
	if elapsed >= duration:
		_explode()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1, 0, 0, 0.2))
	var progress = clamp(elapsed / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * progress, Color(1, 0, 0, 0.5))

func _explode() -> void:
	set_process(false)
	
	if specific_target != null:
		if is_instance_valid(specific_target):
			if global_position.distance_to(specific_target.global_position) <= radius:
				_apply_effects_to(specific_target)
	else:
		for body in get_overlapping_bodies():
			if body == source_entity: continue 
			# Blokada AOE dla sojuszników:
			if not friendly_fire and _is_ally(body): continue
			_apply_effects_to(body)
			
	queue_free()

func _is_ally(body: Node2D) -> bool:
	if not is_instance_valid(source_entity) or not body.has_method("get_node_or_null"): return false
	var my_faction = source_entity.get_node_or_null("FactionComponent")
	if my_faction and body is CharacterEntity:
		return my_faction.get_disposition_toward(body) == FactionComponent.Disposition.FRIENDLY
	return false

func _apply_effects_to(target_node: Node2D) -> void:
	if target_node.has_method("receive_effect"):
		for eff in effects:
			var cloned_eff = eff.duplicate(true)
			# ZABEZPIECZENIE: Sprawdzamy czy sprawca ataku nadal żyje!
			cloned_eff.source_entity = source_entity if is_instance_valid(source_entity) else null
			cloned_eff.source_position = global_position
			target_node.receive_effect(cloned_eff)
