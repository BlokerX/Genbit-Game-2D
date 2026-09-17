extends AIState
class_name StateDialogue

var player_node: Node2D = null

func enter() -> void:
	blackboard.want_to_move = false
	# Zatrzymujemy postać
	if controller.entity.movement_universal_script:
		controller.entity.velocity = Vector2.ZERO

func physics_process(delta: float) -> void:
	# 1. Zabezpieczenie: Jeśli System Zemsty nagle uznał gracza za wroga (HOSTILE),
	# PerceptionComponent znajdzie cel i wpisze go do Blackboarda.
	if blackboard.target != null:
		# Przekazujemy sygnał do Twojego menedżera, by wymusić zamknięcie okna dialogu
		if DialogueManager.has_method("force_close_dialogue"):
			DialogueManager.force_close_dialogue()
		# Wpadamy w szał i ruszamy do walki!
		controller.state_machine.change_state("Chase")
		return
		
	# 2. Płynne obracanie się w stronę gracza podczas rozmowy
	if is_instance_valid(player_node) and controller.behavior_profile and controller.behavior_profile.can_rotate_to_target:
		var target_angle = controller.entity.global_position.angle_to_point(player_node.global_position)
		controller.entity.rotation = lerp_angle(controller.entity.rotation, target_angle, controller.behavior_profile.rotation_speed * delta)
	
	# 3. Jeśli gracz sam odszedł lub skończył rozmowę (DialogueManager wyłączony)
	if not DialogueManager.is_active:
		controller.state_machine.change_state("Idle")
