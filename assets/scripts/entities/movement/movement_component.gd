extends Resource

class_name MovementComponent

# Wartość prędkości:
@export var moveSpeed : float = 0
@export var accelerationMultiplier : float = 5.0
@export var decelerationMultiplier : float = 0.825

func movement_procedure(_delta: float, _velocity: Vector2, _direction: Vector2) -> Vector2 :
	#region D E B U G
	#print("Direction: ", _direction)
	#endregion D E B U G
	
	_direction = _direction.normalized()
	
	_velocity.x += _direction.x * moveSpeed * _delta * accelerationMultiplier
	_velocity.y += _direction.y * moveSpeed * _delta * accelerationMultiplier
	
	_velocity.x = clamp(_velocity.x, -moveSpeed, +moveSpeed)
	_velocity.y = clamp(_velocity.y, -moveSpeed, +moveSpeed)
	
	if is_zero_approx(_direction.x):
		_velocity.x *= decelerationMultiplier
	
	if is_zero_approx(_direction.y):
		_velocity.y *= decelerationMultiplier
	
	return _velocity
	# to use in phisic loop move_and_slide()
