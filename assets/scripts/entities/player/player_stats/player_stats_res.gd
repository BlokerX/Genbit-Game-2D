extends Resource

class_name StatsComponent
	
func get_damage(_damage : int, _health : int, _max_health : int) -> int :
	_health -= _damage
	if _health < 0 :
		_health = 0
	return _health

func heal(_healing : int, _health : int, _max_health : int) -> int :
	_health += _healing
	if _health > _max_health :
		_health = _max_health
	return _health
