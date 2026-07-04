extends TimedEffect
class_name SpeedEffect

@export var speed_multiplier: float = 1.0

func _init(_duration: float = 10.0, _speed_multiplier: float = 1.0) -> void:
	duration = _duration
	speed_multiplier = _speed_multiplier
	tick_interval = 0.0
	effect_name = "SpeedModifier"

# Pomocnicza funkcja wykrywająca właściwy komponent ruchu w obiekcie
func _get_movement_resource(target: Node2D) -> Resource:
	if "movement_universal_script" in target and target.movement_universal_script != null:
		return target.movement_universal_script
	elif "movement_component" in target and target.movement_component != null:
		return target.movement_component
	return null

func on_effect_start(target: Node2D) -> void:
	var movement = _get_movement_resource(target)
	if movement == null:
		push_warning("Cel '" + target.name + "' nie posiada komponentu ruchu!")
		return
		
	if not target.has_meta("base_speed"):
		# Pobieramy bazową prędkość (moveSpeed) z wykrytego zasobu ruchu
		target.set_meta("base_speed", movement.moveSpeed)
		target.set_meta("active_speed_modifiers", [])
		
	var modifiers: Array = target.get_meta("active_speed_modifiers")
	modifiers.append(speed_multiplier)
	
	_apply_speed(target)

func on_effect_end(target: Node2D) -> void:
	var movement = _get_movement_resource(target)
	if movement == null:
		return
		
	if target.has_meta("active_speed_modifiers"):
		var modifiers: Array = target.get_meta("active_speed_modifiers")
		modifiers.erase(speed_multiplier)
		
		if not modifiers.is_empty():
			_apply_speed(target)
		else:
			# Koniec efektów – przywracamy bazową prędkość moveSpeed do zasobu
			movement.moveSpeed = target.get_meta("base_speed")
			print("Gracz ma spowrotem prędkość", movement.moveSpeed)
			
			target.remove_meta("base_speed")
			target.remove_meta("active_speed_modifiers")

func _apply_speed(target: Node2D) -> void:
	var movement = _get_movement_resource(target)
	if movement == null:
		return
		
	var base_speed: float = target.get_meta("base_speed")
	var modifiers: Array = target.get_meta("active_speed_modifiers")
	
	var total_multiplier: float = 1.0
	for mod in modifiers:
		total_multiplier *= mod
		
	# Aplikujemy przemnożoną prędkość do moveSpeed
	movement.moveSpeed = base_speed * total_multiplier
