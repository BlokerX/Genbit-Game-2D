extends AIAbility
class_name StealItemAbility

@export var damage: int = 0
@export var cast_time: float = 0.3

func _init() -> void:
	ability_name = "Kradzież Ekwipunku"
	cooldown = 12.0
	min_range = 0.0
	max_range = 65.0 # Atak w zwarciu!

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	# Podstawowe zabezpieczenie przed startem
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	# Pobieramy kontroler i profil
	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate: bool = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl: 
		combat_ctrl.is_casting_ability = true

	# --- ZWRÓCENIE SIĘ W STRONĘ CELU PRZED ATAKIEM ---
	var aim_direction = attacker.global_position.direction_to(target.global_position)
	if can_rotate:
		attacker.rotation = aim_direction.angle()
	else:
		if attacker.has_method("_update_sprite_direction"):
			attacker._update_sprite_direction(aim_direction)

	# Błyskawiczny cios w kierunku gracza
	var tween = attacker.create_tween()
	var forward_pos = attacker.global_position + aim_direction * 20.0
	tween.tween_property(attacker, "global_position", forward_pos, cast_time / 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(attacker, "global_position", attacker.global_position, cast_time / 2.0).set_trans(Tween.TRANS_SINE)

	# Czekamy na koniec animacji
	await attacker.get_tree().create_timer(cast_time).timeout

	# --- NAPRAWA CRASHA ---
	# Po 'await' musimy bezwzględnie sprawdzić, czy OBAJ uczestnicy nadal żyją!
	if is_instance_valid(attacker) and is_instance_valid(target):
		if attacker.global_position.distance_to(target.global_position) <= max_range + 20.0:
			# Zadajemy obrażenia
			var dmg = DamageEffect.new(damage)
			if target.has_method("receive_effect"):
				target.receive_effect(dmg)
				
			# KRADZIEŻ: Wytrącenie przedmiotu z ekwipunku gracza
			if target.has_method("get_inventory"):
				var inv = target.get_inventory()
				if inv and not inv.get_current_slot().is_empty():
					print(attacker.name + " wytrąca przedmiot graczowi!")
					inv.drop_current_item(true) # Wywołuje wyrzucenie przedmiotu na mapę

	# Przywracamy możliwość działania tylko, jeśli atakujący przetrwał
	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false
