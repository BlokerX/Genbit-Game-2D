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
	
	# TWARDE PRZERWANIE ATAKÓW
	if target.has_method("cancel_current_attack"):
		target.cancel_current_attack()
	
	# 1. Zatrzymujemy standardowy ruch (Działa na starsze moby i gracza)
	target.set_physics_process(false)
	target.set_process(false)
	target.set_process_input(false)
	target.set_process_unhandled_input(false)
	
	# 2. ODCINAMY MÓZG AI (Przestaje wymyślać nowe ataki i nawigować)
	var ai_controller = target.get_node_or_null("AIController")
	if ai_controller:
		ai_controller.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 3. Zatrzymujemy animacje
	if target.has_node("AnimationPlayer"):
		target.get_node("AnimationPlayer").pause()
		
	# 4. PAUZUJEMY TWEENY (Zatrzymuje ataki w połowie lotu/doskoku!)
	if "is_frozen" in target:
		target.is_frozen = true
	if "active_tweens" in target:
		for t in target.active_tweens:
			if t and t.is_valid():
				t.pause()
		
	# 5. Kolorowanie lodu
	if apply_blue_tint:
		var sprite = _get_sprite_from_target(target)
		if sprite != null:
			target.set_meta("original_self_modulate", sprite.self_modulate)
			sprite.self_modulate = freeze_modulate

func on_effect_end(target : Node2D) -> void:
	print("Odmrażam obiekt: ", target.name)
	
	# 1. Przywracamy standardowy ruch
	target.set_physics_process(true)
	target.set_process(true)
	target.set_process_input(true)
	target.set_process_unhandled_input(true)
	
	# 2. BUDZIMY MÓZG AI 
	var ai_controller = target.get_node_or_null("AIController")
	if ai_controller:
		ai_controller.process_mode = Node.PROCESS_MODE_INHERIT
	
	# 3. Wznawiamy animacje
	if target.has_node("AnimationPlayer"):
		target.get_node("AnimationPlayer").play()
		
	# 4. WZNAWIAMY TWEENY (Atak z przed zamrożenia leci dalej)
	if "is_frozen" in target:
		target.is_frozen = false
	if "active_tweens" in target:
		for t in target.active_tweens:
			if t and t.is_valid():
				t.play()
		
	# 5. Przywracamy oryginalny kolor ofiary
	var sprite = _get_sprite_from_target(target)
	if sprite != null and target.has_meta("original_self_modulate"):
		sprite.self_modulate = target.get_meta("original_self_modulate")
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
