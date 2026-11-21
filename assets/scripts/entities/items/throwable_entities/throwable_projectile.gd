extends Area2D
class_name ThrowableProjectile
## Niematerialny pocisk miotany (np. nóż do rzucania, strzałka, mina) oparty na Area2D i RayCastach.
## Generuje lekką smugę ruchu dobieraną automatycznie do żywiołu/efektu (np. zieleń trucizny dla zatrutego noża - DRY / OCP).

#region Stałe Wizualne i Fizyczne (Brak magicznych liczb)
const DEFAULT_TRAIL_COLOR := Color(0.90, 0.94, 1.0, 0.90)
const MIN_TRAIL_VELOCITY_SQ: float = 25.0
const TRAIL_REFERENCE_SPEED_PX: float = 300.0
#endregion

@export_category("Wizualizacje")
@export var main_sprite: Sprite2D
@export var activated_texture: Texture2D
## Czy rysować dwuwarstwową smugę podczas lotu (automatycznie wyłączona, gdy obiekt stoi w miejscu, np. Mina)?
@export var enable_trail: bool = true
## Maksymalna długość smugi ciągnącej się za lecącą rzutką (w pikselach).
@export_range(6.0, 80.0, 2.0) var trail_length_px: float = 24.0
## Grubość zewnętrznej poświaty smugi za rzutką (w pikselach).
@export_range(1.0, 10.0, 0.2) var trail_width_px: float = 3.0
## Opcjonalny własny kolor smugi. Gdy przezroczysty (alpha == 0), kolor dobierany jest z efektów rzutki (np. trucizna -> zieleń).
@export var override_vfx_color: Color = Color(0.0, 0.0, 0.0, 0.0)

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
var _traveled_distance: float = 0.0
var _was_drawing_trail: bool = false
var _resolved_trail_color: Color = DEFAULT_TRAIL_COLOR

func _ready() -> void:
	add_to_group("Hazard")
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()

	_resolved_trail_color = _resolve_trail_color()
	_explosive_ctrl.cache_shooter_faction(shooter)

func _physics_process(delta: float) -> void:
	if _explosive_ctrl.process_timers(self, delta, lifetime, is_infinite, activation_delay):
		return

	if current_velocity.length_squared() > 0.0:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
		var move_vector: Vector2 = current_velocity * delta

		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
		query.collision_mask = collision_mask

		if is_instance_valid(shooter) and shooter is CollisionObject2D:
			query.exclude = [(shooter as CollisionObject2D).get_rid()]

		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			global_position = result["position"]
			current_velocity = Vector2.ZERO
			if destroy_on_impact:
				trigger_effect(result["collider"] as Node2D)
		else:
			global_position += move_vector
			_traveled_distance += move_vector.length()

	if enable_trail:
		var is_moving_fast: bool = current_velocity.length_squared() >= MIN_TRAIL_VELOCITY_SQ
		if is_moving_fast:
			_was_drawing_trail = true
			queue_redraw()
		elif _was_drawing_trail:
			_was_drawing_trail = false
			queue_redraw()

func _draw() -> void:
	if not enable_trail or current_velocity.length_squared() < MIN_TRAIL_VELOCITY_SQ:
		return

	var speed_factor: float = clampf(current_velocity.length() / TRAIL_REFERENCE_SPEED_PX, 0.25, 1.0)
	var current_len: float = minf(trail_length_px * speed_factor, _traveled_distance)
	CombatVFXHelper.draw_motion_trail(
		self,
		current_velocity,
		global_rotation,
		current_len,
		trail_width_px,
		_resolved_trail_color
	)

func _resolve_trail_color() -> Color:
	if override_vfx_color.a > 0.0:
		return override_vfx_color
	return CombatVFXHelper.resolve_color_from_effects(effects_to_apply, DEFAULT_TRAIL_COLOR)

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
