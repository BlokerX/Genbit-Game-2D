extends Area2D
class_name ThrowableProjectile

@export_category("Wizualizacje")
@export var main_sprite: Sprite2D 
@export var activated_texture: Texture2D 

@export_category("Ustawienia Obiektu")
@export var destroy_on_impact: bool = true
@export var activation_delay: float = 0.0 
@export var activate_on_trigger: bool = true 
@export var activate_on_damage: bool = false 
@export var friendly_fire: bool = false 
@export var lifetime: float = 3.0 
@export var is_infinite: bool = false
@export var can_be_knocked_back: bool = true 

@export_category("Obszar Działania (Opcjonalne)")
@export var aoe_area: Area2D

var shooter: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var friction: float = 0.0
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

func _ready() -> void:
	add_to_group("Hazard")
	body_entered.connect(_on_body_entered)
	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if not is_infinite and _time_alive >= lifetime:
		trigger_effect(null) 
		return

	if current_velocity.length() > 0:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
		
	var move_vector = current_velocity * delta

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
	query.collision_mask = collision_mask 
	if shooter != null and shooter is CollisionObject2D:
		query.exclude = [shooter.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		global_position = result.position
		current_velocity = Vector2.ZERO
		if destroy_on_impact:
			trigger_effect(result.collider as Node2D)
	else:
		global_position += move_vector

func _on_body_entered(body: Node2D) -> void:
	if not destroy_on_impact: 
		return
		
	trigger_effect(body)

func trigger_effect(direct_hit: Node2D) -> void:
	if direct_hit == shooter:
		if not friendly_fire or _time_alive < 0.1:
			return

	if is_queued_for_deletion() or has_meta("is_triggered"):
		return
	set_meta("is_triggered", true)

	if main_sprite != null and activated_texture != null:
		main_sprite.texture = activated_texture

	if activation_delay > 0.0 and direct_hit == null:
		await get_tree().create_timer(activation_delay).timeout
		if not is_inside_tree():
			return

	var targets: Array[Node2D] = []
	
	if aoe_area != null:
		targets.append_array(aoe_area.get_overlapping_bodies())
		for area in aoe_area.get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
	elif self is Area2D and not destroy_on_impact:
		targets.append_array(get_overlapping_bodies())
		for area in get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
		
	if direct_hit != null and not targets.has(direct_hit):
		targets.append(direct_hit)
		
	for body in targets:
		# Zabezpieczamy się sprawdzając czy shooter nadal istnieje
		if is_instance_valid(shooter) and body == shooter and not friendly_fire:
			continue
			
		# Zabezpieczenie sojuszników przed friendly fire!
		if not friendly_fire and _is_ally(body):
			continue
			
		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				if "source_position" in effect:
					effect.source_position = self.global_position
					
				# --- KLUCZOWA POPRAWKA PROWOKACJI I BŁĘDU CRASHU ---
				if "source_entity" in effect:
					effect.source_entity = shooter if is_instance_valid(shooter) else null
					
				body.receive_effect(effect)

	# --- 3. USUNIĘCIE OBIEKTU PO WYBUCHU ---
	queue_free()

func receive_effect(effect: Effect) -> bool:
	if effect is TriggerEffect:
		if activate_on_trigger and not is_queued_for_deletion():
			trigger_effect(null)
		return true
		
	if effect is DamageEffect:
		if activate_on_damage and not is_queued_for_deletion():
			trigger_effect(null)
		return true
	
	if effect is KnockbackEffect:
		if not can_be_knocked_back:
			return true
		return effect.apply_effect(self)
	
	return effect.apply_effect(self)

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
