extends Effect
class_name KnockbackEffect

@export var knockback_force: float = 800.0
@export var duration: float = 0.25

var source_position: Vector2 = Vector2.ZERO

func _init(_force: float = 800.0, _duration: float = 0.25):
	effect_name = "Knockback"
	effect_color = Color.PALE_VIOLET_RED
	knockback_force = _force
	duration = _duration

func apply_effect(target: Node2D) -> bool:
	var dir = source_position.direction_to(target.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT 
		
	# 1. Nasze rzucane obiekty (Bomby fizyczne, wirtualne Noże, Miny)
	if target is ThrowableEntity:
		var me: Node = target
		# Jeśli zrobiliśmy bombę jako RigidBody2D
		if me is RigidBody2D:
			(me as RigidBody2D).apply_central_impulse(dir * knockback_force)
		# Jeśli zrobiliśmy nóż/minę jako Area2D, dodajemy wektor prędkości
		elif me is Area2D:
			target.current_velocity += dir * knockback_force
		return true

	# 2. Obiekty fizyczne na scenie (np. upuszczony loot ItemPickup lub dynamiczne beczki)
	elif target is RigidBody2D:
		target.apply_central_impulse(dir * knockback_force)
		return true
		
	# 3. Postacie (Gracz, Pająki i inni wrogowie z klas CharacterBody2D)
	elif target is CharacterBody2D:
		var tween = target.create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		
		tween.tween_method(
			func(vel: Vector2):
				if is_instance_valid(target):
					var old_vel = target.velocity
					target.velocity = vel
					target.move_and_slide()
					target.velocity = old_vel,
			dir * knockback_force, 
			Vector2.ZERO, 
			duration
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		
		return true
		
	return false
