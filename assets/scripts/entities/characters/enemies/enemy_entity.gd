extends CharacterEntity

class_name EnemyEntity


#region AI

@export_category("AI")

## Główny kontroler sztucznej inteligencji.
@export var ai_controller: AIController


#endregion


#region Initialization

func _ready() -> void:
	super()

	if ai_controller == null:
		push_warning(
			"%s nie posiada przypisanego AIController."
			% name
		)
		return

	ai_controller.initialize(self)


#endregion
