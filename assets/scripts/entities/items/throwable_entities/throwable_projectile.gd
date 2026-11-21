extends Area2D
class_name ThrowableProjectile
## Niematerialny pocisk miotany (np. nóż do rzucania, strzałka, mina) oparty na Area2D i RayCastach.
## Wspiera wybór stylu śladu (TRAIL vs DROPLET vs AUTO) współdzielony z Projectile (SOLID - SRP / OCP / DRY)
## oraz obsługuje punkt zapalnika/diody (domyślnie środek obiektu dla miny).

#region Stałe Wizualne i Fizyczne (Brak magicznych liczb)
const DEFAULT_TRAIL_COLOR := Color(0.90, 0.94, 1.0, 0.90)
const MIN_TRAIL_VELOCITY_SQ: float = 25.0
const TRAIL_REFERENCE_SPEED_PX: float = 300.0
const MIN_TRAIL_GROWTH_RATIO: float = 0.35
#endregion

@export_category("Wizualizacje")
@export var main_sprite: Sprite2D
@export var activated_texture: Texture2D
## Wybór stylu śladu podczas lotu (nieaktywny, gdy obiekt stoi w miejscu np. Mina):
## NONE (brak), TRAIL (smuga za rzutką), DROPLET (kropla otaczająca czubek), AUTO (kropla dla żywiołów, smuga dla zwykłych).
@export var trail_style: CombatVFXHelper.TrailStyle = CombatVFXHelper.TrailStyle.AUTO
## Maksymalna długość zwężającego się ogona smugi / kropli za rzutką (w pikselach).
@export_range(6.0, 80.0, 2.0) var trail_length_px: float = 24.0
## Szerokość u podstawy dla trybu TRAIL (smuga wyłącznie za rzutką).
@export_range(1.0, 14.0, 0.5) var trail_width_px: float = 5.0
## Wysunięcie zaokrąglonego przodu kropli przed środek rzutki dla trybu DROPLET (w pikselach).
@export_range(0.0, 30.0, 1.0) var droplet_head_lead_px: float = 13.0
## Szerokość otoczki kropli w najszerszym miejscu dla trybu DROPLET (w pikselach).
@export_range(2.0, 30.0, 0.5) var droplet_width_px: float = 13.0
## Opcjonalny własny kolor smugi. Gdy przezroczysty (alpha == 0), kolor dobierany jest z efektów (np. trucizna -> zieleń).
@export var override_vfx_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Opcjonalna ścieżka knota w układzie lokalnym. Pusta tablica oznacza środek (0, 0) — idealne dla miny!
@export var fuse_path_points: PackedVector2Array = PackedVector2Array()

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
var _resolved_trail_style: CombatVFXHelper.TrailStyle = CombatVFXHelper.TrailStyle.NONE
var _resolved_trail_color: Color = DEFAULT_TRAIL_COLOR

func _ready() -> void:
	add_to_group("Hazard")
	body_entered.connect(_on_body_entered)

	if current_velocity != Vector2.ZERO:
		rotation = current_velocity.angle()

	var has_elemental: bool = CombatVFXHelper.has_elemental_effect(effects_to_apply)
	_resolved_trail_style = CombatVFXHelper.resolve_trail_style(trail_style, has_elemental)
	_resolved_trail_color = _resolve_trail_color()
	_explosive_ctrl.cache_shooter_faction(shooter)

func _physics_process(delta: float) -> void:
	if _explosive_ctrl.process_timers(
		self, delta, lifetime, is_infinite, activation_delay, false, fuse_path_points
	):
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

	if _resolved_trail_style != CombatVFXHelper.TrailStyle.NONE:
		var is_moving_fast: bool = current_velocity.length_squared() >= MIN_TRAIL_VELOCITY_SQ
		if is_moving_fast:
			_was_drawing_trail = true
			queue_redraw()
		elif _was_drawing_trail:
			_was_drawing_trail = false
			queue_redraw()

func _draw() -> void:
	if _resolved_trail_style == CombatVFXHelper.TrailStyle.NONE or current_velocity.length_squared() < MIN_TRAIL_VELOCITY_SQ:
		return

	var is_droplet: bool = (_resolved_trail_style == CombatVFXHelper.TrailStyle.DROPLET)
	var width_px: float = droplet_width_px if is_droplet else trail_width_px
	var speed_factor: float = clampf(current_velocity.length() / TRAIL_REFERENCE_SPEED_PX, 0.35, 1.0)
	var growth_factor: float = clampf(_traveled_distance / maxf(1.0, trail_length_px * 0.5), MIN_TRAIL_GROWTH_RATIO, 1.0)
	var current_tail: float = minf(trail_length_px * speed_factor, _traveled_distance)
	if is_droplet:
		current_tail = minf(trail_length_px * speed_factor, maxf(width_px, _traveled_distance))

	CombatVFXHelper.draw_projectile_trail(
		self,
		_resolved_trail_style,
		current_velocity,
		global_rotation,
		droplet_head_lead_px * growth_factor,
		current_tail,
		width_px,
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
		self, shooter, direct_hit, friendly_fire, activation_delay, main_sprite, activated_texture, fuse_path_points
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
