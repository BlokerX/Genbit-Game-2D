class_name QuestObjectiveProgressController
extends RefCounted

## Aktualizuje postępy celów aktywnych zadań na podstawie zdarzenia gry.
func process_game_event(
	event_type: String,
	event_data: Dictionary,
	active_quests: Dictionary,
	quest_db: Dictionary,
	objective_progressed_callback: Callable,
	advance_quest_callback: Callable
) -> void:
	for quest_id in active_quests.keys():
		var quest: QuestData = quest_db[quest_id]
		var quest_state: Dictionary = active_quests[quest_id]
		var stage_index: int = quest_state["stage"]

		if stage_index >= quest.stages.size():
			continue

		var stage: QuestStage = quest.stages[stage_index]
		var stage_completed := true

		for objective_index in range(stage.objectives.size()):
			var objective: QuestObjective = stage.objectives[objective_index]
			if objective == null:
				continue

			var current_count: int = quest_state["progress"].get(objective_index, 0)
			var required_count: int = objective.get_required_amount()
			if current_count >= required_count:
				continue

			# Przekazujemy obecny postęp i dostajemy nowy!
			var updated_count: int = objective.check_event(
				event_type,
				event_data,
				current_count
			)

			if updated_count != current_count:
				quest_state["progress"][objective_index] = updated_count
				objective_progressed_callback.call(quest, objective_index, updated_count)
				print(
					"QuestManager: Postęp w celu '",
					objective.objective_description,
					"' (",
					updated_count,
					"/",
					required_count,
					")"
				)

			# Jeśli postęp wciąż jest mniejszy niż wymagany, blokujemy awans etapu
			if updated_count < required_count:
				stage_completed = false

		# Auto-awans, jeśli wszystkie cele w etapie są gotowe!
		if stage.objectives.size() > 0 and stage_completed:
			print("QuestManager: Wszystkie cele ukończone! Automatyczny awans etapu dla: ", quest.title)
			advance_quest_callback.call(quest_id)
