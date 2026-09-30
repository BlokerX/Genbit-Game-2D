extends TimedEffect
class_name ImmortalityEffect

func _init(_duration: float = 10.0):
	effect_name = "Immortality"
	effect_color = Color.GOLD
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	target.set_meta("is_immortal", true)
	
	# Opcjonalny efekt wizualny: postać zaczyna świecić na żółto
	var sprite = _get_sprite(target)
	if sprite:
		target.set_meta("pre_immortal_color", sprite.modulate)
		sprite.modulate = Color(1.5, 1.5, 0.5, 1.0) # Lekki żółty blask (Overdrive RGB)

func on_effect_end(target: Node2D) -> void:
	target.remove_meta("is_immortal")
	
	var sprite = _get_sprite(target)
	if sprite and target.has_meta("pre_immortal_color"):
		sprite.modulate = target.get_meta("pre_immortal_color")
		target.remove_meta("pre_immortal_color")

func _get_sprite(target: Node2D) -> Node:
	if "character_sprite" in target and target.character_sprite != null:
		return target.character_sprite
	elif target.has_node("Sprite2D"):
		return target.get_node("Sprite2D")
	return null
