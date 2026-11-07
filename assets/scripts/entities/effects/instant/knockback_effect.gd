extends Effect
class_name KnockbackEffect

const DEFAULT_KNOCKBACK_FORCE: float = 800.0
const DEFAULT_KNOCKBACK_DURATION: float = 0.25
const FULL_CC_RESISTANCE: float = 1.0

@export var knockback_force: float = DEFAULT_KNOCKBACK_FORCE
@export var duration: float = DEFAULT_KNOCKBACK_DURATION

func _init(_force: float = DEFAULT_KNOCKBACK_FORCE, _duration: float = DEFAULT_KNOCKBACK_DURATION):
	effect_name = "Knockback"
	effect_color = Color.PALE_VIOLET_RED
	effect_category = EffectCategory.KNOCKBACK
	knockback_force = _force
	duration = _duration

func apply_effect(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false

	var final_knockback: float = knockback_force

	# --- ODCZYT ODPORNOŚCI NA ODRZUT (TENACITY) ---
	if target.get("health_stats_script") != null:
		var cc_res: float = float(target.health_stats_script.cc_resistance)
		if cc_res >= FULL_CC_RESISTANCE:
			print("Cel ma 100% odporności. Ignoruje odrzut!")
			return false
		final_knockback *= (1.0 - clampf(cc_res, 0.0, FULL_CC_RESISTANCE))
	# ----------------------------------------------

	var dir: Vector2 = source_position.direction_to(target.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# 1. WSZYSTKIE OBIEKTY FIZYCZNE (RigidBody2D)
	if target is RigidBody2D:
		target.apply_central_impulse(dir * final_knockback)
		return true

	# 2. NIEMATERIALNE RZUTKI (ThrowableProjectile)
	elif target is ThrowableProjectile:
		target.current_velocity += dir * final_knockback
		return true

	# 3. POSTACIE (Gracz, Wrogowie na bazie CharacterBody2D)
	# Używamy move_and_collide z ześlizgiem po ścianie zamiast drugiego move_and_slide(),
	# dzięki czemu odrzut NIGDY nie przebije ściany i nie wypchnie postaci poza mapę!
	elif target is CharacterBody2D:
		var body: CharacterBody2D = target as CharacterBody2D
		var tween: Tween = body.create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_method(
			func(current_push_vel: Vector2):
				if not is_instance_valid(body) or not body.is_inside_tree():
					return
				var step_delta: float = body.get_physics_process_delta_time()
				var step_motion: Vector2 = current_push_vel * step_delta
				var collision: KinematicCollision2D = body.move_and_collide(step_motion)
				if collision != null:
					var slide_remainder: Vector2 = collision.get_remainder().slide(collision.get_normal())
					if slide_remainder.length_squared() > 0.01:
						body.move_and_collide(slide_remainder),
			dir * final_knockback,
			Vector2.ZERO,
			duration
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		return true

	return false

func is_offensive() -> bool:
	return true
