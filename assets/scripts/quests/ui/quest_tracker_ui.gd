extends MarginContainer # <--- ZMIANA z CanvasLayer
class_name QuestTrackerUI

## Kolory i symbole kategorii używane przez nagłówek oraz cele nieukończonego zadania.
const CATEGORY_COLORS := {
	QuestData.QuestCategory.MAIN_STORY: Color(1.0, 0.8, 0.2),
	QuestData.QuestCategory.SIDE_QUEST: Color(0.6, 0.8, 1.0),
	QuestData.QuestCategory.CONTRACT: Color(0.9, 0.4, 0.4),
	QuestData.QuestCategory.HIDDEN: Color(0.75, 0.55, 0.95),
}

const CATEGORY_MARKERS := {
	QuestData.QuestCategory.MAIN_STORY: "✦",
	QuestData.QuestCategory.SIDE_QUEST: "✧",
	QuestData.QuestCategory.CONTRACT: "⚔",
	QuestData.QuestCategory.HIDDEN: "◆",
}

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
			timer_label.text = "%02d:%02d" % [floori(t / 60.0), int(t) % 60]
			timer_label.show()
		else:
			timer_label.hide()

func _on_tracked_changed(quest_id: StringName) -> void:
	if quest_id == &"" or not QuestManager.active_quests.has(quest_id):
		container.hide()
		return
		
	var quest: QuestData = QuestManager.quest_db[quest_id]
	_apply_quest_category_style(quest)
	_rebuild_objectives(quest)
	container.show()

## Dopasowuje kolor i symbol nagłówka do kategorii śledzonego zadania.
func _apply_quest_category_style(quest: QuestData) -> void:
	var category_color: Color = CATEGORY_COLORS.get(
		quest.category,
		CATEGORY_COLORS[QuestData.QuestCategory.MAIN_STORY]
	)
	var category_marker: String = CATEGORY_MARKERS.get(
		quest.category,
		CATEGORY_MARKERS[QuestData.QuestCategory.MAIN_STORY]
	)
	title_label.text = "%s %s" % [category_marker, quest.title]
	title_label.add_theme_color_override("font_color", category_color)

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
	var category_color: Color = CATEGORY_COLORS.get(
		quest.category,
		CATEGORY_COLORS[QuestData.QuestCategory.MAIN_STORY]
	)
	var category_color_html := category_color.to_html(false)
	for i in range(stage.objectives.size()):
		var obj = stage.objectives[i]
		if obj == null: continue
		var current = q_data["progress"].get(i, 0)
		var required = obj.get_required_amount()
		
		if current >= required: text += "[color=#66cc66]✓ " + obj.objective_description + "[/color]\n"
		else: text += "[color=#" + category_color_html + "]○ " + obj.objective_description + " (" + str(current) + "/" + str(required) + ")[/color]\n"
		
	objectives_label.text = text
