extends Effect
class_name UpdateQuestEffect

@export_group("Aktualizacja Zadania")
## Przeciągnij tutaj zasób QuestData z folderu!
@export var quest: QuestData 

## Na który etap ustawić zadanie? (0 to początek)
@export var stage_to_set: int = 0

## Zaznacz, jeśli ten dialog całkowicie kończy zadanie
@export var mark_as_completed: bool = false

func _init() -> void:
	effect_name = "Update Quest"

func apply_effect(_target: Node2D) -> bool:
	if quest == null:
		push_error("UpdateQuestEffect: Nie przypisano zasobu questa!")
		return false
		
	if mark_as_completed:
		QuestManager.complete_quest(quest.id)
	else:
		QuestManager.update_quest(quest.id, stage_to_set)
		
	return true
