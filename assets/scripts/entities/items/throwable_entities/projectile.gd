extends Area2D

const MAX_ALLY_PENETRATIONS: int = 5
const SPRITE_ROTATION_OFFSET_RAD: float = 0

@export var speed: float = 600.0
@export var lifetime: float = 4.0
@export var friendly_fire: bool = false

var direction: Vector2 = Vector2.ZERO
var effects_to_apply: Array[Effect] = []

var _time_alive: float = 0.0
var shooter: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Zachowujemy pionowy offset rotacji tekstury pocisku nadany przez RangedWeaponComponent
	rotation = direction.angle() + SPRITE_ROTATION_OFFSET_RAD

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	var remaining_dist: float = speed * delta
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * remaining_dist
	)
	query.collision_mask = collision_mask

	var excluded_rids: Array[RID] = []
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		excluded_rids.append(shooter.get_rid())
	query.exclude = excluded_rids

	var hit_valid_target: bool = false
	var max_penetrations: int = MAX_ALLY_PENETRATIONS

	# Pętla penetrująca: jeśli trafimy sojusznika, ignorujemy go i skanujemy dalej
	while max_penetrations > 0:
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			var col: Node2D = result["collider"] as Node2D
			var hit_pos: Vector2 = result["position"]
			if not friendly_fire and _is_ally(col):
				# Trafiono sojusznika: dodajemy go do wyjątków, przesuwamy początek promienia i szukamy dalej
				if col is CollisionObject2D:
					excluded_rids.append(col.get_rid())
					query.exclude = excluded_rids
				query.from = hit_pos
				max_penetrations -= 1
			else:
				# Trafiono prawowity cel (Wróg / Ściana)
				global_position = hit_pos
				_on_body_entered(col)
				hit_valid_target = true
				break
		else:
			break # Pusta przestrzeń

	if not hit_valid_target:
		global_position += direction * remaining_dist

func _on_body_entered(body: Node2D) -> void:
	if body == null or body == shooter:
		return
	if not friendly_fire and _is_ally(body):
		return # Przelatuje przez ciało sojusznika!

	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	else:
		return

	set_deferred("monitoring", false)

	if body.has_method("receive_effect"):
		for effect in effects_to_apply:
			if effect != null:
				var cloned_eff: Effect = effect.duplicate(true)
				cloned_eff.source_position = self.global_position
				cloned_eff.source_entity = shooter if is_instance_valid(shooter) else null
				body.receive_effect(cloned_eff)

	queue_free()

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie
func _is_ally(body: Node2D) -> bool:
	if not is_instance_valid(shooter) or not is_instance_valid(body): 
		return false
	if body == shooter:
		return true

	var my_faction = shooter.get_node_or_null("FactionComponent")
	if not my_faction:
		return false

	if body.has_node("FactionComponent"):
		return my_faction.get_disposition_toward(body) == FactionComponent.Disposition.FRIENDLY

	return false
