extends MarginContainer # <--- ZMIANA z CanvasLayer
class_name QuestTrackerUI

@onready var container: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var objectives_label: RichTextLabel = $VBoxContainer/ObjectivesLabel
@onready var timer_label: Label = $VBoxContainer/TimerLabel

func _ready() -> void:
	# Usuwamy ustawianie warstwy (layer = ...), bo jesteśmy teraz wewnątrz UI_Canvas!
	container.hide()
	
	QuestManager.quest_tracked_changed.connect(_on_tracked_changed)
	QuestManager.quest_objective_progressed.connect(_on_progressed)
	QuestManager.quest_updated.connect(_on_updated)
	
	# Inicjalizacja przy starcie
	_on_tracked_changed(QuestManager.tracked_quest_id)

func _process(_delta: float) -> void:
	var q_id = QuestManager.tracked_quest_id
	if q_id != &"" and QuestManager.active_quests.has(q_id):
		var q_data = QuestManager.active_quests[q_id]
		if q_data.has("timer") and q_data["timer"] > 0.0:
			var t = q_data["timer"]
			timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
			timer_label.show()
		else:
			timer_label.hide()

func _on_tracked_changed(quest_id: StringName) -> void:
	if quest_id == &"" or not QuestManager.active_quests.has(quest_id):
		container.hide()
		return
		
	var quest: QuestData = QuestManager.quest_db[quest_id]
	title_label.text = quest.title
	_rebuild_objectives(quest)
	container.show()

func _on_progressed(quest: QuestData, _idx: int, _count: int) -> void:
	if QuestManager.tracked_quest_id == quest.id: _rebuild_objectives(quest)

func _on_updated(quest: QuestData, _stage: int) -> void:
	if QuestManager.tracked_quest_id == quest.id: _rebuild_objectives(quest)

func _rebuild_objectives(quest: QuestData) -> void:
	var q_data = QuestManager.active_quests[quest.id]
	var stage_idx = q_data["stage"]
	if stage_idx >= quest.stages.size(): return
	
	var stage: QuestStage = quest.stages[stage_idx]
	var text = ""
	for i in range(stage.objectives.size()):
		var obj = stage.objectives[i]
		if obj == null: continue
		var current = q_data["progress"].get(i, 0)
		var required = obj.get_required_amount()
		
		if current >= required: text += "[color=#66cc66]✓ " + obj.objective_description + "[/color]\n"
		else: text += "[color=#cccccc]○ " + obj.objective_description + " (" + str(current) + "/" + str(required) + ")[/color]\n"
		
	objectives_label.text = text
