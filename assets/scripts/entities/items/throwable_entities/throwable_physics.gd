extends RigidBody2D
class_name ThrowablePhysics
## Fizyczny obiekt miotany lub stawiany (np. granat, mina zbliżeniowa) oparty na RigidBody2D.

const DAMP_DIVISOR: float = 100.0
const MAX_REPORTED_CONTACTS: int = 5

@export_category("Wizualizacje")
@export var main_sprite: Sprite2D
@export var activated_texture: Texture2D

@export_category("Ustawienia Obiektu")
@export var destroy_on_impact: bool = false
## Opóźnienie (w sekundach) przed faktycznym wyzwoleniem efektu wybuchu/aktywacji.
@export var activation_delay: float = 0.0
## Czy uruchamia swoje główne działanie po trafieniu czystym TriggerEffect?
@export var activate_on_trigger: bool = true
## Czy uruchamia swoje główne działanie pod wpływem obrażeń (DamageEffect)?
@export var activate_on_damage: bool = false
@export var friendly_fire: bool = false
@export var lifetime: float = 3.0
@export var is_infinite: bool = false
@export var arming_delay: float = 0.4
## True: Fala wybuchu odpycha obiekt. False: Obiekt jest zakotwiczony (np. Mina).
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
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	gravity_scale = 0.0
	linear_damp = friction / DAMP_DIVISOR
	contact_monitor = true
	max_contacts_reported = MAX_REPORTED_CONTACTS
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()
		apply_central_impulse(current_velocity)

	_explosive_ctrl.cache_shooter_faction(shooter)

	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

		# Przywracamy kolizję ze strzelcem po arming_delay TYLKO wtedy, gdy friendly_fire == true!
		# Dzięki temu strzelec nie potyka się fizycznie o własne miny/granaty, gdy friendly_fire jest wyłączone.
		if friendly_fire and arming_delay > 0.0:
			get_tree().create_timer(arming_delay).timeout.connect(func():
				if not is_inside_tree():
					return
				if is_instance_valid(self) and is_instance_valid(shooter):
					remove_collision_exception_with(shooter)
			)

func _physics_process(delta: float) -> void:
	_explosive_ctrl.process_timers(self, delta, lifetime, is_infinite, activation_delay)

func _on_body_entered(body: Node) -> void:
	if not destroy_on_impact:
		return
	var body_2d: Node2D = body as Node2D
	if body_2d != null:
		trigger_effect(body_2d)

func trigger_effect(direct_hit: Node2D) -> void:
	_explosive_ctrl.handle_trigger(
		self, shooter, direct_hit, friendly_fire, activation_delay, main_sprite, activated_texture
	)

func _execute_explosion(direct_hit: Node2D) -> void:
	_explosive_ctrl.execute_explosion(
		self, shooter, direct_hit, aoe_area, null, friendly_fire, effects_to_apply, true
	)

func receive_effect(effect: Effect) -> bool:
	return _explosive_ctrl.handle_received_effect(
		self, effect, activate_on_trigger, activate_on_damage, can_be_knocked_back
	)

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie.
func _is_ally(body: Node2D) -> bool:
	return FactionComponent.is_ally_of(shooter, body, _explosive_ctrl.shooter_faction_name)
