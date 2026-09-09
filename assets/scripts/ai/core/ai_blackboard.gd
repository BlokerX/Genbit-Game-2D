extends RefCounted

class_name AIBlackboard


#region References

## Postać, do której należy ten Blackboard.
var entity: EnemyEntity


#endregion


#region Target

## Aktualny cel AI.
var target: CharacterEntity = null

## Ostatnia znana pozycja celu.
var last_known_position: Vector2 = Vector2.ZERO

## Czy AI posiada aktualnie ostatnią znaną pozycję celu?
var has_last_known_position: bool = false


#endregion


#region Spatial information

## Odległość od aktualnego celu.
var target_distance: float = INF

## Kierunek od AI do celu.
var target_direction: Vector2 = Vector2.ZERO

var want_to_move: bool = false

#endregion


#region Initialization

func initialize(owner_entity: EnemyEntity) -> void:
	entity = owner_entity


#endregion
