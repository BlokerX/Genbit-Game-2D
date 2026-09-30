extends TimedEffect
class_name GhostEffect

func _init(_duration: float = 8.0):
	effect_name = "Ghost Mode"
	effect_color = Color.GHOST_WHITE
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	target.set_meta("is_ghost", true)
	
	if target is CollisionObject2D:
		target.set_meta("original_layer", target.collision_layer)
		target.set_meta("original_mask", target.collision_mask)
		
		# layer = 0 -> inni nas nie widzą
		target.collision_layer = 0
		# mask = 0 -> my nie widzimy fizyki (przenikamy przez ściany!)
		target.collision_mask = 0
		
	var sprite = _get_sprite(target)
	if sprite:
		sprite.modulate.a = 0.4 # Półprzezroczystość

func on_effect_end(target: Node2D) -> void:
	target.remove_meta("is_ghost")
	
	if target is CollisionObject2D:
		if target.has_meta("original_layer"):
			target.collision_layer = target.get_meta("original_layer")
			target.remove_meta("original_layer")
		if target.has_meta("original_mask"):
			target.collision_mask = target.get_meta("original_mask")
			target.remove_meta("original_mask")
		
	var sprite = _get_sprite(target)
	if sprite:
		sprite.modulate.a = 1.0

func _get_sprite(target: Node2D) -> Node:
	if "character_sprite" in target and target.character_sprite != null:
		return target.character_sprite
	elif target.has_node("Sprite2D"):
		return target.get_node("Sprite2D")
	return null
