extends TimedEffect
class_name InvisibilityEffect

func _init(_duration: float = 12.0):
	effect_name = "Invisibility"
	effect_color = Color.TRANSPARENT
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	target.set_meta("is_invisible", true)
	
	var sprite = _get_sprite(target)
	if sprite:
		sprite.modulate.a = 0.15 # Ledwie widoczny kontur dla gracza
		
	# Jeśli to gracz, usuwamy go z grupy, by AI zgubiło z niego celownik
	# (Wymaga dopisania go z powrotem przy zdejmowaniu efektu!)
	if target.is_in_group("Player"):
		target.remove_from_group("Player")

func on_effect_end(target: Node2D) -> void:
	target.remove_meta("is_invisible")
	
	var sprite = _get_sprite(target)
	if sprite:
		sprite.modulate.a = 1.0
		
	# Zwracamy gracza do grupy celów dla AI
	if target is PlayerCharacter and not target.is_in_group("Player"):
		target.add_to_group("Player")

func _get_sprite(target: Node2D) -> Node:
	if "character_sprite" in target and target.character_sprite != null:
		return target.character_sprite
	elif target.has_node("Sprite2D"):
		return target.get_node("Sprite2D")
	return null
