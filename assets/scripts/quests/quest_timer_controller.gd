class_name QuestTimerController
extends RefCounted

## Aktualizuje timery aktywnych zadań oraz cooldowny zadań powtarzalnych.
func process_timers(
	delta: float,
	active_quests: Dictionary,
	quest_db: Dictionary,
	cooldown_quests: Dictionary,
	completed_quests: Array[StringName],
	failed_quests: Array[StringName],
	fail_quest_callback: Callable
) -> void:
	# 1. Odliczanie czasu dla aktywnych questów czasowych
	var quests_to_fail: Array[StringName] = []
	for quest_id in active_quests.keys():
		if active_quests[quest_id].has("timer") and active_quests[quest_id]["timer"] > 0:
			active_quests[quest_id]["timer"] -= delta
			if active_quests[quest_id]["timer"] <= 0:
				print("QuestManager: Czas na wykonanie zadania [", quest_db[quest_id].title, "] minął!")
				quests_to_fail.append(quest_id)

	for quest_id in quests_to_fail:
		fail_quest_callback.call(quest_id)

	# 2. Odliczanie cooldownu dla questów powtarzalnych
	var quests_to_reset: Array[StringName] = []
	for quest_id in cooldown_quests.keys():
		cooldown_quests[quest_id] -= delta
		if cooldown_quests[quest_id] <= 0:
			quests_to_reset.append(quest_id)

	for quest_id in quests_to_reset:
		cooldown_quests.erase(quest_id)
		# POPRAWKA 3: Czyścimy OBA słowniki (sukcesy i porażki)
		completed_quests.erase(quest_id)
		failed_quests.erase(quest_id)
		if quest_db.has(quest_id):
			print("QuestManager: Zadanie powtarzalne [", quest_db[quest_id].title, "] jest znów dostępne.")
