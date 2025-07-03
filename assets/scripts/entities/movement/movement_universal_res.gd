extends Resource

class_name MovementComponent

func movement_procedure(_delta: float, _velocity: Vector2, _moveSpeed: float, _accelerationMultiplayer: float, _decelerationMultiplayer: float, _direction: Vector2) -> Vector2 :
	#region D E B U G
	#print("Direction: ", _direction)
	#endregion D E B U G
	
	_direction = _direction.normalized()
	
	_velocity.x += _direction.x * _moveSpeed * _delta * _accelerationMultiplayer
	_velocity.y += _direction.y * _moveSpeed * _delta * _accelerationMultiplayer
	
	_velocity.x = clamp(_velocity.x, -_moveSpeed, +_moveSpeed)
	_velocity.y = clamp(_velocity.y, -_moveSpeed, +_moveSpeed)
	
	if !_direction.x :
		_velocity.x *= _decelerationMultiplayer
	
	if !_direction.y :
		_velocity.y *= _decelerationMultiplayer
	
	return _velocity
	# to use in phisic loop move_and_slide()
