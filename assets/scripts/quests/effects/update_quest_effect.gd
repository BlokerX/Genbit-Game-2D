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

@export_group("Zabezpieczenia Chronologii")
## Jeśli włączone, zadanie zaktualizuje się TYLKO, jeśli gracz jest DOKŁADNIE na wskazanym etapie. Zapobiega to łamaniu fabuły, gdy gracz zrobi coś za wcześnie/za późno.
@export var enforce_chronology: bool = false
## Oczekiwany obecny etap zadania (używane tylko, gdy enforce_chronology = true).
@export var required_current_stage: int = 0

func _init() -> void:
	effect_name = "Update Quest"

func apply_effect(_target: Node2D) -> bool:
	if quest == null:
		push_error("UpdateQuestEffect: Nie przypisano zasobu questa!")
		return false
		
	# --- TARCZA CHRONOLOGII ---
	if enforce_chronology:
		# Sprawdzamy, czy zadanie jest w ogóle aktywne
		if not QuestManager.active_quests.has(quest.id):
			print("UpdateQuestEffect: Odrzucono. Zadanie '%s' nie jest aktywne." % quest.id)
			return false
			
		var current_stage = QuestManager.active_quests[quest.id]["stage"]
		if current_stage != required_current_stage:
			print("UpdateQuestEffect: Blokada chronologii. Oczekiwano etapu %d, ale gracz jest na %d." % [required_current_stage, current_stage])
			return false
	# --------------------------

	if mark_as_completed:
		QuestManager.complete_quest(quest.id)
	elif mode == UpdateMode.ADVANCE_NEXT_STAGE:
		QuestManager.advance_to_next_stage(quest.id)
	elif mode == UpdateMode.SET_SPECIFIC_STAGE:
		QuestManager.update_quest(quest.id, specific_stage)
		
	return true
