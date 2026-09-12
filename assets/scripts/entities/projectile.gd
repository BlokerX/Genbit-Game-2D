extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 4.0
@export var friendly_fire: bool = false # <--- NOWA FLAGA

var direction := Vector2.ZERO
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0
var shooter: Node2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta):
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	var remaining_dist = speed * delta
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * remaining_dist)
	query.collision_mask = collision_mask
	
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		query.exclude = [shooter.get_rid()]

	var hit_valid_target = false
	var max_penetrations = 5 # Limit pętli (zabezpieczenie przed krashem)
	
	# Pętla penetrująca: jeśli trafimy sojusznika, ignorujemy go i skanujemy dalej
	while max_penetrations > 0:
		var result = space_state.intersect_ray(query)
		if result:
			var col = result.collider
			if not friendly_fire and _is_ally(col):
				# Trafiono sojusznika: dodajemy go do wyjątków, przesuwamy początek promienia i szukamy dalej
				if col is CollisionObject2D:
					query.exclude.append(col.get_rid())
				query.from = result.position
				max_penetrations -= 1
			else:
				# Trafiono prawowity cel (Wróg / Ściana)
				global_position = result.position
				_on_body_entered(col)
				hit_valid_target = true
				break
		else:
			break # Pusta przestrzeń

	if not hit_valid_target:
		global_position += direction * remaining_dist

func _on_body_entered(body: Node2D):
	if body == shooter: return
	if not friendly_fire and _is_ally(body): return # Przelatuje przez ciało sojusznika
	
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	else:
		return
		
	set_deferred("monitoring", false)

	if body.has_method("receive_effect"):
		for effect in effects_to_apply:
			effect.source_position = self.global_position
			effect.source_entity = shooter if is_instance_valid(shooter) else null
			body.receive_effect(effect)

	queue_free()

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie
func _is_ally(body: Node2D) -> bool:
	if not is_instance_valid(shooter) or not is_instance_valid(body): 
		return false
		
	# Pobierz frakcję strzelca
	var my_faction = shooter.get_node_or_null("FactionComponent")
	if not my_faction:
		return false
		
	# Sprawdź czy ofiara MA jakikolwiek FactionComponent (Duck Typing zamiast Class checking)
	if body.has_node("FactionComponent"):
		return my_faction.get_disposition_toward(body) == FactionComponent.Disposition.FRIENDLY
		
	return false
