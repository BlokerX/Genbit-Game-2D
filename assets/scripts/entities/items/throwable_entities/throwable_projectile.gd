extends Area2D
class_name ThrowableProjectile
## Niematerialny pocisk miotany (np. nóż do rzucania, strzałka, szybki granat) oparty na Area2D i RayCastach.

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

var _explosive_ctrl: ThrowableExplosiveController = ThrowableExplosiveController.new()

func _ready() -> void:
	add_to_group("Hazard")
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()

	_explosive_ctrl.cache_shooter_faction(shooter)

func _physics_process(delta: float) -> void:
	if _explosive_ctrl.process_timers(self, delta, lifetime, is_infinite, activation_delay):
		return

	if current_velocity.length() > 0.0:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
		var move_vector: Vector2 = current_velocity * delta

		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
		query.collision_mask = collision_mask 

		if is_instance_valid(shooter) and shooter is CollisionObject2D:
			query.exclude = [shooter.get_rid()]

		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			global_position = result["position"]
			current_velocity = Vector2.ZERO
			if destroy_on_impact:
				trigger_effect(result["collider"] as Node2D)
		else:
			global_position += move_vector

func _on_body_entered(body: Node2D) -> void:
	if not destroy_on_impact: 
		return
	trigger_effect(body)

func trigger_effect(direct_hit: Node2D) -> void:
	_explosive_ctrl.handle_trigger(
		self, shooter, direct_hit, friendly_fire, activation_delay, main_sprite, activated_texture
	)

func _execute_explosion(direct_hit: Node2D) -> void:
	var fallback_area: Area2D = self if not destroy_on_impact else null
	_explosive_ctrl.execute_explosion(
		self, shooter, direct_hit, aoe_area, fallback_area, friendly_fire, effects_to_apply, false
	)

func receive_effect(effect: Effect) -> bool:
	return _explosive_ctrl.handle_received_effect(
		self, effect, activate_on_trigger, activate_on_damage, can_be_knocked_back
	)

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie.
func _is_ally(body: Node2D) -> bool:
	return FactionComponent.is_ally_of(shooter, body, _explosive_ctrl.shooter_faction_name)
