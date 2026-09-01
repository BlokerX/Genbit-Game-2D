extends ItemCondition
class_name FlagCondition

@export var flag_name: String = "quest_name"
@export var required_state: bool = true

func check_condition(_actor: Node2D, _item: ItemInstance) -> bool:
	return DialogueState.has_flag(flag_name) == required_state
