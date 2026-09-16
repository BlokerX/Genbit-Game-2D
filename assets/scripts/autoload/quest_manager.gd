extends Node

signal quest_started(quest: QuestData)
signal quest_updated(quest: QuestData, current_stage: int)
signal quest_completed(quest: QuestData)

var quest_db: Dictionary = {}
var active_quests: Dictionary = {} 
var completed_quests: Array[StringName] = []

func _ready() -> void:
	# Wczytuje wszystkie pliki .tres questów przy starcie
	_load_all_quests("res://assets/data/quests/")

func update_quest(quest_id: StringName, stage_index: int) -> void:
	if completed_quests.has(quest_id) or not quest_db.has(quest_id): return
		
	var quest: QuestData = quest_db[quest_id]
	
	# Zabezpieczenie przed wyjściem poza tablicę etapów
	if stage_index < 0 or stage_index >= quest.stages.size():
		push_error("QuestManager: Nieprawidłowy indeks etapu dla Questa: ", quest_id)
		return
		
	var stage_data: QuestStage = quest.stages[stage_index]
	var is_new_quest = not active_quests.has(quest_id)
	
	active_quests[quest_id] = stage_index
	
	if is_new_quest:
		quest_started.emit(quest)
		print("Quest: Rozpoczęto zadanie [", quest.title, "]")
	else:
		quest_updated.emit(quest, stage_index)
		print("Quest: Zaktualizowano zadanie [", quest.title, "]")

	# AUTOMATYKA: Wysłanie zdarzenia w świat
	if stage_data.trigger_event_on_start != "":
		EventBus.story_event_triggered.emit(stage_data.trigger_event_on_start)
		
	# AUTOMATYKA: Przyznanie nagród etapu (np. klucza)
	_grant_rewards(stage_data.start_rewards)

func complete_quest(quest_id: StringName) -> void:
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)
		completed_quests.append(quest_id)
		
		var quest: QuestData = quest_db[quest_id]
		quest_completed.emit(quest)
		print("Quest: Zakończono zadanie [", quest.title, "]")
		
		# Finałowe zdarzenia w świecie
		if quest.completion_event != "":
			EventBus.story_event_triggered.emit(quest.completion_event)
			
		# Finałowe nagrody
		_grant_rewards(quest.completion_rewards)

## Pomocnicza funkcja nakładająca efekty (nagrody) na Gracza
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
