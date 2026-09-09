extends Node

class_name AIController


#region References

## Postać, którą kontroluje ten AI.
var entity: EnemyEntity


## Blackboard przechowujący aktualne informacje AI.
var blackboard: AIBlackboard


#endregion


#region Initialization

func initialize(owner_entity: EnemyEntity) -> void:
	entity = owner_entity

	blackboard = AIBlackboard.new()

	blackboard.initialize(entity)

	print(
		"AIController initialized for: ",
		entity.name
	)


#endregion
