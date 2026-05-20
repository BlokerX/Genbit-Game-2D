extends TimedEffect
class_name SpeedEffect

@export var speed_multiplier: float = 1.0

func _init(_duration: float = 10.0, _speed_multiplier: float = 1.0) -> void:
	duration = _duration
	speed_multiplier = _speed_multiplier
	tick_interval = 0.0
	effect_name = "SpeedModifier"

func on_effect_start(target: Node2D) -> void:
	# todo naprawić to normalnie bez meta
	if not target.has_meta("base_speed"):
		# UWAGA: Podmień "target.speed" na swoją zmienną prędkości
		target.set_meta("base_speed", target.speed)
		target.set_meta("active_speed_modifiers", [])
		
	var modifiers: Array = target.get_meta("active_speed_modifiers")
	modifiers.append(speed_multiplier)
	
	_apply_speed(target)

func on_effect_end(target: Node2D) -> void:
	if target.has_meta("active_speed_modifiers"):
		var modifiers: Array = target.get_meta("active_speed_modifiers")
		modifiers.erase(speed_multiplier)
		
		if not modifiers.is_empty():
			_apply_speed(target)
		else:
			# Koniec wszystkich efektów szybkości - wracamy do bazy
			# UWAGA: Podmień "target.speed" na swoją zmienną prędkości
			target.speed = target.get_meta("base_speed")
			
			target.remove_meta("base_speed")
			target.remove_meta("active_speed_modifiers")

func _apply_speed(target: Node2D) -> void:
	var base_speed: float = target.get_meta("base_speed")
	var modifiers: Array = target.get_meta("active_speed_modifiers")
	
	var total_multiplier: float = 1.0
	for mod in modifiers:
		total_multiplier *= mod
		
	# UWAGA: Podmień "target.speed" na swoją zmienną prędkości
	target.speed = base_speed * total_multiplier
