extends Effect
class_name UpdateQuestEffect

enum UpdateMode { 
	ADVANCE_NEXT_STAGE,  ## Automatycznie przesuwa zadanie o 1 krok do przodu (Najlepsze i najbezpieczniejsze)
	SET_SPECIFIC_STAGE   ## Wymusza wejście na konkretny etap (Dobre do rozgałęzień fabularnych)
}

@export_group("Aktualizacja Zadania")
## Przeciągnij tutaj zasób QuestData z folderu!
@export var quest: QuestData 

@export var mode: UpdateMode = UpdateMode.ADVANCE_NEXT_STAGE

## Używane TYLKO, jeśli tryb to SET_SPECIFIC_STAGE
@export var specific_stage: int = 0

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
	elif mode == UpdateMode.ADVANCE_NEXT_STAGE:
		QuestManager.advance_to_next_stage(quest.id)
	elif mode == UpdateMode.SET_SPECIFIC_STAGE:
		QuestManager.update_quest(quest.id, specific_stage)
		
	return true
