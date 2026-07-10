extends TimedEffect
class_name FreezeEffect

# Domyślnie nałożona, ale możesz to odznaczyć w edytorze.
@export var apply_blue_tint: bool = true

@export var freeze_modulate: Color = Color(0.337, 0.341, 1.0, 0.502)

func _init(_duration: float = 2.0, _apply_blue_tint: bool = true):
	effect_name = "Freeze"
	effect_color = Color.CYAN
	duration = _duration
	apply_blue_tint = _apply_blue_tint
	tick_interval = 0.0 # 0, ponieważ nie potrzebujemy "tików", działa to jako twardy stan

func on_effect_start(target : Node2D) -> void:
	print("Zamrażam obiekt: ", target.name, " na ", duration, " sekund!")
	
	# Odcinamy logikę i input
	target.set_physics_process(false)
	target.set_process(false)
	target.set_process_input(false)
	target.set_process_unhandled_input(false)
	
	# Zatrzymujemy animacje
	if target.has_node("AnimationPlayer"):
		target.get_node("AnimationPlayer").pause()
		
	# Zmieniamy kolor TYLKO, jeśli flaga jest prawdziwa
	if apply_blue_tint:
		var sprite = _get_sprite_from_target(target)
		if sprite != null:
			# Zapisujemy oryginalny kolor wewnątrz ofiary
			target.set_meta("original_self_modulate", sprite.self_modulate)
			sprite.self_modulate = freeze_modulate # Lodowy niebieski

func on_effect_end(target : Node2D) -> void:
	print("Odmrażam obiekt: ", target.name)
	
	# Przywracamy wejścia i logikę
	target.set_physics_process(true)
	target.set_process(true)
	target.set_process_input(true)
	target.set_process_unhandled_input(true)
	
	# Wznawiamy animacje
	if target.has_node("AnimationPlayer"):
		target.get_node("AnimationPlayer").play()
		
	# Przywracamy oryginalny kolor ofiary
	# Wystarczy sprawdzić, czy zapisaliśmy oryginalny kolor - jeśli tak, to znaczy, że flaga była aktywna
	var sprite = _get_sprite_from_target(target)
	if sprite != null and target.has_meta("original_self_modulate"):
		sprite.self_modulate = target.get_meta("original_self_modulate")
		# Czyścimy metadane po zakończeniu efektu
		target.remove_meta("original_self_modulate")

# Funkcja pomocnicza do znajdowania obrazka ofiary
func _get_sprite_from_target(target: Node2D) -> Node:
	if "character_sprite" in target and target.character_sprite != null:
		return target.character_sprite
	elif target.has_node("Sprite2D"):
		return target.get_node("Sprite2D")
	elif target.has_node("AnimatedSprite2D"):
		return target.get_node("AnimatedSprite2D")
	return null
