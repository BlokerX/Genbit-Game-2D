extends AbilityComponent
class_name CameraShakeAbilityComponent
## Komponent zdolności AI wywołujący wstrząs kamery gracza w wybranym momencie cyklu życia zdolności (SOLID - SRP / DRY).

## Określa zdarzenie wyzwalające drżenie kamery.
enum ShakeTrigger {
	ON_AREA_DETONATED, ## Przy detonacji strefy / wybuchu / każdym tiku wiązki.
	ON_PLAYER_HIT,     ## Wyłącznie wtedy, gdy zdolność faktycznie trafi gracza.
	ON_ANY_TARGET_HIT, ## Gdy zdolność trafi dowolną istotę w zasięgu.
	ON_CAST_START      ## Natychmiast przy rozpoczęciu rzucania zdolności.
}

@export_group("Wstrząs Kamery")
## Moment wywołania wstrząsu kamery.
@export var trigger_mode: ShakeTrigger = ShakeTrigger.ON_AREA_DETONATED
## Siła drżenia kamery (trauma przekazywana do CameraComponent).
@export_range(0.05, 2.0, 0.05) var trauma_amount: float = 0.45

func on_cast_started(_ability: Resource, attacker: CharacterEntity, _target: Variant) -> void:
	if trigger_mode == ShakeTrigger.ON_CAST_START:
		AIAbility.trigger_camera_shake(attacker, trauma_amount)

func on_area_detonated(_ability: Resource, attacker: CharacterEntity, _origin_pos: Vector2, _radius: float) -> void:
	if trigger_mode == ShakeTrigger.ON_AREA_DETONATED:
		AIAbility.trigger_camera_shake(attacker, trauma_amount)

func on_target_hit(_ability: Resource, attacker: CharacterEntity, target: Node2D, _origin_pos: Vector2) -> void:
	if trigger_mode == ShakeTrigger.ON_PLAYER_HIT:
		if is_instance_valid(target) and target.is_in_group("Player"):
			AIAbility.trigger_camera_shake(target, trauma_amount)
	elif trigger_mode == ShakeTrigger.ON_ANY_TARGET_HIT:
		var context: Node = attacker if is_instance_valid(attacker) else target
		AIAbility.trigger_camera_shake(context, trauma_amount)
