extends AbilityComponent
class_name NpcAmnesiaAbilityComponent
## Komponent zdolności AI czyszczący pamięć celu u trafionych jednostek AI (amnezja / dezorientacja - SOLID SRP).
## Może być podpięty do dowolnego archetypu zdolności w pliku .tres.

@export_group("Dezorientacja AI (Amnezja)")
## Nazwa stanu maszyny stanów, do którego przechodzi zdezorientowane AI po utracie celu.
@export var fallback_state_name: String = "Idle"
## Czy wyczyścić również zapamiętaną ostatnią znaną pozycję celu?
@export var clear_last_known_position: bool = true

func on_target_hit(_ability: Resource, _attacker: CharacterEntity, target: Node2D, _origin_pos: Vector2) -> void:
	if not is_instance_valid(target) or not target.has_node("AIController"):
		return
	var target_ai: Node = target.get_node("AIController")
	if target_ai == null or target_ai.get("blackboard") == null:
		return

	target_ai.blackboard.target = null
	if clear_last_known_position:
		target_ai.blackboard.has_last_known_position = false
	target_ai.blackboard.want_to_move = false

	if target_ai.get("state_machine") != null and fallback_state_name != "":
		target_ai.state_machine.change_state(fallback_state_name)
