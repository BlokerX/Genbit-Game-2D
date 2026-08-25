extends Node2D
class_name ThrowableEntity

@export_category("Ustawienia Obiektu")
@export var lifetime: float = 3.0 ## Czas do zniszczenia/wybuchu
@export var destroy_on_impact: bool = true ## True: Nóż (wybucha od razu), False: Bomba (czeka na lifetime)
@export var friendly_fire: bool = false ## Czy wybuch/trafienie może zranić strzelającego (Gracza)?
@export var arming_delay: float = 0.4 ## Czas (w sekundach) zanim fizyczny obiekt (RigidBody) zacznie kolidować ze strzelcem.

@export_category("Obszar Działania (Opcjonalne)")
## Jeśli podepniesz tutaj węzeł Area2D, efekty uderzą we WSZYSTKO w tym obszarze (Bomba).
## Jeśli zostawisz to puste, efekty uderzą tylko w cel, w który bezpośrednio wpadł obiekt (Nóż/Shuriken).
@export var aoe_area: Area2D

var shooter: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var friction: float = 0.0
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

func _ready() -> void:
	var me: Node = self 

	# --- SCENARIUSZ 1: OBIEKT FIZYCZNY ---
	if me is RigidBody2D:
		var rigid: RigidBody2D = me as RigidBody2D
		rigid.gravity_scale = 0.0
		rigid.linear_damp = friction / 100.0
		rigid.contact_monitor = true
		rigid.max_contacts_reported = 5
		rigid.body_entered.connect(_on_body_entered)

		if current_velocity != Vector2.ZERO:
			rigid.rotation = current_velocity.angle()
			rigid.apply_central_impulse(current_velocity)

		if shooter != null and shooter is CollisionObject2D:
			rigid.add_collision_exception_with(shooter)
			
			# Używamy zmiennej z Inspektora zamiast sztywnego 0.4!
			if arming_delay > 0.0:
				get_tree().create_timer(arming_delay).timeout.connect(func():
					if is_instance_valid(self) and is_instance_valid(shooter):
						rigid.remove_collision_exception_with(shooter)
				)
			
	# --- SCENARIUSZ 2: OBIEKT NIEMATERIALNY ---
	elif me is Area2D:
		var area: Area2D = me as Area2D
		area.body_entered.connect(_on_body_entered)
		if current_velocity != Vector2.ZERO:
			rotation = current_velocity.angle()

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		trigger_effect(null) # Wywołanie przez upływ czasu (brak bezpośredniego celu)
		return

	var me: Node = self 

	if me is Area2D:
		var area: Area2D = me as Area2D
		
		if current_velocity.length() > 0:
			current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
			
		var move_vector = current_velocity * delta

		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
		
		query.collision_mask = area.collision_mask 
		if shooter != null and shooter is CollisionObject2D:
			query.exclude = [shooter.get_rid()]

		var result = space_state.intersect_ray(query)
		if result:
			global_position = result.position
			current_velocity = Vector2.ZERO
			if destroy_on_impact:
				trigger_effect(result.collider) # Zderzenie z użyciem RayCastu
		else:
			global_position += move_vector

func _on_body_entered(body: Node2D) -> void:
	if not destroy_on_impact: 
		return
		
	trigger_effect(body) # Zderzenie fizyczne

## Wywołuje nakładanie efektów. Może przyjąć cel, który bezpośrednio uderzono.
func trigger_effect(direct_hit: Node2D) -> void:
	
	# Zabezpieczenie przed uderzeniem samego siebie w 1 klatce
	if direct_hit == shooter:
		if not friendly_fire or _time_alive < 0.1:
			return

	var targets: Array[Node2D] = []
	
	# 1. Jeśli to broń obszarowa, pobieramy wszystkich w zasięgu
	if aoe_area != null:
		targets = aoe_area.get_overlapping_bodies()
		
	# 2. Upewniamy się, że cel bezpośredni również dostał obrażenia 
	if direct_hit != null and not targets.has(direct_hit):
		targets.append(direct_hit)
		
	# 3. Rozdzielamy efekty dla każdego zebranego celu
	for body in targets:
		if body == shooter and not friendly_fire:
			continue
			
		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				# ---> Jeśli to Knockback, mówimy mu, gdzie leży bomba/item! <---
				if effect is KnockbackEffect:
					effect.source_position = self.global_position
					
				body.receive_effect(effect)
				
	# Tu możesz dodać instancjonowanie cząsteczek wybuchu (VFX)
	queue_free()

## Odbieranie efektów środowiskowych (pozwala na odpychanie bomby przez inną bombę!)
func receive_effect(effect: Effect) -> bool:
	return effect.apply_effect(self)
