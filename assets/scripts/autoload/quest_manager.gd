extends Node

signal quest_started(quest: QuestData)
signal quest_updated(quest: QuestData, current_stage: int)
signal quest_objective_progressed(quest: QuestData, objective_index: int, current_count: int)
signal quest_completed(quest: QuestData)

var quest_db: Dictionary = {}
# active_quests teraz przechowuje słownik z etapem i postępem celów:
# { quest_id: { "stage": int, "progress": Dictionary } }
var active_quests: Dictionary = {} 
var completed_quests: Array[StringName] = []

func _ready() -> void:
	_load_all_quests("res://assets/data/quests/")
	
	# Nasłuchujemy całego świata! (Upewnij się, że masz ten sygnał w event_bus.gd)
	if EventBus.has_signal("game_event_occurred") and not EventBus.game_event_occurred.is_connected(_on_game_event):
		EventBus.game_event_occurred.connect(_on_game_event)

# --- SYSTEM CZUJNIKÓW I CELÓW ---
func _on_game_event(event_type: String, event_data: Dictionary) -> void:
	for quest_id in active_quests.keys():
		var quest: QuestData = quest_db[quest_id]
		var q_data: Dictionary = active_quests[quest_id]
		var stage_idx: int = q_data["stage"]
		
		if stage_idx >= quest.stages.size(): continue
			
		var stage: QuestStage = quest.stages[stage_idx]
		var stage_completed = true
		
		for i in range(stage.objectives.size()):
			var objective: QuestObjective = stage.objectives[i]
			if objective == null: continue
			
			var current_val: int = q_data["progress"].get(i, 0)
			var required_val: int = objective.get_required_amount()
			
			# Przekazujemy obecny postęp i dostajemy nowy!
			var new_val = objective.check_event(event_type, event_data, current_val)
			
			if new_val != current_val:
				q_data["progress"][i] = new_val
				quest_objective_progressed.emit(quest, i, new_val)
				print("QuestManager: Postęp w celu '", objective.objective_description, "' (", new_val, "/", required_val, ")")
				
			# Jeśli postęp wciąż jest mniejszy niż wymagany, blokujemy awans etapu
			if new_val < required_val:
				stage_completed = false
		
		# Auto-awans, jeśli wszystkie cele w etapie są gotowe!
		if stage.objectives.size() > 0 and stage_completed:
			advance_to_next_stage(quest_id)

# --- ZARZĄDZANIE ETAPAMI ---
## Pcha questa bezpiecznie o 1 etap do przodu
func advance_to_next_stage(quest_id: StringName) -> void:
	if completed_quests.has(quest_id): return
	var current_stage = -1
	if active_quests.has(quest_id):
		current_stage = active_quests[quest_id]["stage"]
	update_quest(quest_id, current_stage + 1)

func update_quest(quest_id: StringName, stage_index: int) -> void:
	if completed_quests.has(quest_id) or not quest_db.has(quest_id): return
		
	var quest: QuestData = quest_db[quest_id]
	if stage_index >= quest.stages.size():
		complete_quest(quest_id)
		return
		
	var current_stage = -1
	if active_quests.has(quest_id):
		current_stage = active_quests[quest_id]["stage"]
		
	if stage_index <= current_stage: return
		
	var stage_data: QuestStage = quest.stages[stage_index]
	var is_new_quest = not active_quests.has(quest_id)
	
	active_quests[quest_id] = {
		"stage": stage_index,
		"progress": {}
	}
	
	if is_new_quest:
		quest_started.emit(quest)
		print("Quest: Rozpoczęto zadanie [", quest.title, "]")
	else:
		quest_updated.emit(quest, stage_index)
		print("Quest: Zaktualizowano zadanie [", quest.title, "]")
	
	if stage_data.trigger_event_on_start != "":
		EventBus.story_event_triggered.emit(stage_data.trigger_event_on_start)
	_grant_rewards(stage_data.start_rewards)
	
	# --- MAGIA: Jeśli dopiero co otrzymaliśmy zadanie, natychmiast odpytujemy ekwipunek Gracza! ---
	# Dzięki temu, jeśli gracz MIAŁ JUŻ pistolet w plecaku, cel automatycznie się zaliczy.
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_inventory"):
		_on_game_event("inventory_changed", {"inventory": player.get_inventory()})

func complete_quest(quest_id: StringName) -> void:
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)
		completed_quests.append(quest_id)
		
		var quest: QuestData = quest_db[quest_id]
		quest_completed.emit(quest)
		print("Quest: Zakończono zadanie [", quest.title, "]")
		
		if quest.completion_event != "":
			EventBus.story_event_triggered.emit(quest.completion_event)
		_grant_rewards(quest.completion_rewards)

func _grant_rewards(rewards: Array[Effect]) -> void:
	if rewards.is_empty(): return
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("receive_effect"):
		for effect in rewards:
			if effect != null:
				player.receive_effect(effect.duplicate(true))

func _load_all_quests(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.replace(".remap", "").ends_with(".tres"):
			var res = load(path.path_join(file_name.replace(".remap", "")))
			if res is QuestData:
				quest_db[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
