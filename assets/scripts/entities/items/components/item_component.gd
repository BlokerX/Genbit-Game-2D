class_name ItemComponent
extends Resource

@export_group("Warunki (Conditions)")
@export var conditions: Array[ItemCondition]

## Opcjonalna funkcja - wywoływana przy tworzeniu przedmiotu
func initialize_state(_item_instance: ItemInstance) -> void:
	pass

## Sprawdza, czy wszystkie warunki do wykonania akcji są spełnione
func can_execute(actor: Node2D, item_instance: ItemInstance) -> bool:
	for condition in conditions:
		if not condition.check_condition(actor, item_instance):
			return false
	return true

## Główna funkcja wykonawcza
func execute(_actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	pass
