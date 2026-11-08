class_name ItemComponent
extends Resource

@export_group("Warunki (Conditions)")
@export var conditions: Array[ItemCondition]

## Opcjonalna funkcja - wywoływana przy tworzeniu przedmiotu
func initialize_state(_item_instance: ItemInstance) -> void:
	pass

## Tworzy płytką kopię komponentu z własną, niezależną instancją AttackData oraz tablicami efektów.
## Gwarantuje, że ulepszenie statystyk jednego miecza/karabinu nie zmieni statystyk innych przedmiotów,
## jednocześnie nie duplikując w RAM-ie tekstur, dźwięków i scen pocisków!
func create_unique_copy() -> ItemComponent:
	var copy: ItemComponent = duplicate(false) as ItemComponent
	if conditions != null:
		copy.conditions = conditions.duplicate()
	if "attack_data" in copy and copy.get("attack_data") != null:
		copy.set("attack_data", copy.get("attack_data").duplicate(false))
	if "effects" in copy and copy.get("effects") is Array:
		copy.set("effects", copy.get("effects").duplicate())
	if "weapon_effects" in copy and copy.get("weapon_effects") is Array:
		copy.set("weapon_effects", copy.get("weapon_effects").duplicate())
	if "passive_buffs" in copy and copy.get("passive_buffs") is Array:
		copy.set("passive_buffs", copy.get("passive_buffs").duplicate())
	return copy

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
