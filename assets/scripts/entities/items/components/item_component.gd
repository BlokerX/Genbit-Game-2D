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
		# ZABEZPIECZENIE: Ignorujemy puste pola w Inspektorze
		if condition != null:
			if not condition.check_condition(actor, item_instance):
				return false
	return true

## CZYSTA FASADA: Wrapper, który Gracz wywołuje tylko raz, bez martwienia się o warunki.
func try_execute(actor: Node2D, target: Node2D, item_instance: ItemInstance) -> bool:
	if not can_execute(actor, item_instance):
		return false
		
	execute(actor, target, item_instance)
	return true

## Główna funkcja wykonawcza
func execute(_actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	pass
