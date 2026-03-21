extends Resource

class_name MovementComponent

# Wartość prędkości:
@export var moveSpeed : float = 0
@export var accelerationMultiplayer : float = 0
@export var decelerationMultiplayer : float = 0

func movement_procedure(_delta: float, _velocity: Vector2, _direction: Vector2) -> Vector2 :
	#region D E B U G
	#print("Direction: ", _direction)
	#endregion D E B U G
	
	_direction = _direction.normalized()
	
	_velocity.x += _direction.x * moveSpeed * _delta * accelerationMultiplayer
	_velocity.y += _direction.y * moveSpeed * _delta * accelerationMultiplayer
	
	_velocity.x = clamp(_velocity.x, -moveSpeed, +moveSpeed)
	_velocity.y = clamp(_velocity.y, -moveSpeed, +moveSpeed)
	
	if !_direction.x :
		_velocity.x *= decelerationMultiplayer
	
	if !_direction.y :
		_velocity.y *= decelerationMultiplayer
	
	return _velocity
	# to use in phisic loop move_and_slide()
