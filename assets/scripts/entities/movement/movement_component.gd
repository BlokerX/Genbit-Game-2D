extends Resource

class_name MovementComponent

# Wartość prędkości:
@export var moveSpeed : float = 0
@export var accelerationMultiplier : float = 5.0
@export var decelerationMultiplier : float = 0.275

func movement_procedure(_delta: float, _velocity: Vector2, _direction: Vector2) -> Vector2 :
	_direction = _direction.normalized()
	
	if _direction != Vector2.ZERO:
		_velocity.x += _direction.x * moveSpeed * _delta * accelerationMultiplier
		_velocity.y += _direction.y * moveSpeed * _delta * accelerationMultiplier
		# Zabezpieczenie przed "szybkim skosem" (limitujemy długość całego wektora, a nie oś x i y osobno)
		_velocity = _velocity.limit_length(moveSpeed)
	else:
		# Prawidłowe hamowanie niezależne od FPS (z użyciem move_toward i delta)
		# Zakładamy, że decelerationMultiplier to teraz np. 1500 (wartość utraty prędkości na sekundę)
		# Jeśli nie chcesz zmieniać wartości w Inspektorze, przemnóżmy starą wartość przez moveSpeed * 10
		var friction = moveSpeed * decelerationMultiplier * _delta * 10.0
		_velocity.x = move_toward(_velocity.x, 0, friction)
		_velocity.y = move_toward(_velocity.y, 0, friction)

	return _velocity
	# to use in phisic loop move_and_slide()
