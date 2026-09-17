extends CanvasLayer
class_name QuestLogUI

@export_group("Referencje UI - Lewy Panel")
@export var quest_list_container: Container

@export_group("Referencje UI - Prawy Panel")
@export var right_panel: Control
@export var title_label: Label
@export var description_label: RichTextLabel
@export var objectives_label: RichTextLabel
@export var timer_label: Label
@export var abandon_button: Button

@export_group("Opcjonalne Elementy")
@export var close_button: Button

var _selected_quest_id: StringName = &""
var _buttons_dict: Dictionary = {}

func _ready() -> void:
	layer = GameLayers.UI_HUD 
	hide()
	if right_panel: right_panel.hide()
	
	if abandon_button:
		abandon_button.pressed.connect(_on_abandon_button_pressed)
	if close_button:
		close_button.pressed.connect(close_log)
	
	QuestManager.quest_started.connect(_on_quest_list_changed)
	QuestManager.quest_updated.connect(_on_quest_list_changed)
	QuestManager.quest_completed.connect(_on_quest_finished)
	QuestManager.quest_failed.connect(_on_quest_finished)
	QuestManager.quest_objective_progressed.connect(_on_objective_progressed)

# --- SYSTEM WEJŚCIA DLA CANVAS LAYER ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleQuestLog"):
		if visible:
			close_log()
		elif not DialogueManager.is_active:
			open_log()
		get_viewport().set_input_as_handled()
		
	# Zamknij dziennik, gdy naciśniesz ESC lub np. Ekwipunek
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ToggleInventory")):
		close_log()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible or _selected_quest_id == &"": return
	var active_quests = QuestManager.active_quests
	if active_quests.has(_selected_quest_id):
		var q_data = active_quests[_selected_quest_id]
		if q_data.has("timer") and q_data["timer"] > 0.0:
			var time_left = q_data["timer"]
			var minutes = int(time_left) / 60
			var seconds = int(time_left) % 60
			timer_label.text = "Pozostały czas: %02d:%02d" % [minutes, seconds]
			timer_label.show()
		else:
			timer_label.hide()

func open_log() -> void:
	# Wysyłamy sygnał do UIControllera, by zamknął skrzynie i wyłączył HUD
	EventBus.open_fullscreen_menu.emit("QuestLog")
	
	show()
	get_tree().paused = true
	EventBus.set_menu_state(EventBus.MENU_QUEST_LOG, true)
	
	_refresh_quest_list()
	if QuestManager.active_quests.has(_selected_quest_id):
		_select_quest(_selected_quest_id)
	elif QuestManager.active_quests.size() > 0:
		_select_quest(QuestManager.active_quests.keys()[0])
	else:
		right_panel.hide()
		
	await get_tree().process_frame
	if _buttons_dict.has(_selected_quest_id):
		_buttons_dict[_selected_quest_id].grab_focus()
	elif close_button:
		close_button.grab_focus()

func close_log() -> void:
	if not visible: return
	hide()
	EventBus.set_menu_state(EventBus.MENU_QUEST_LOG, false)
	
	if not EventBus.is_any_menu_open():
		get_tree().paused = false

# --- REAKCJE NA ZDARZENIA ---
func _on_quest_list_changed(_quest: QuestData, _stage: int = 0) -> void:
	if visible:
		_refresh_quest_list()
		if _selected_quest_id == _quest.id: _select_quest(_quest.id)

func _on_objective_progressed(quest: QuestData, _obj_idx: int, _count: int) -> void:
	if visible and _selected_quest_id == quest.id: _build_objectives_text(quest)

func _on_quest_finished(quest: QuestData) -> void:
	if _selected_quest_id == quest.id:
		_selected_quest_id = &""
		right_panel.hide()
	if visible: _refresh_quest_list()

func _on_abandon_button_pressed() -> void:
	if _selected_quest_id != &"": QuestManager.abandon_quest(_selected_quest_id)

# --- LOGIKA RYSOWANIA UI KATEGORII ZADAŃ ---
func _refresh_quest_list() -> void:
	if quest_list_container == null: return
	for child in quest_list_container.get_children(): child.queue_free()
	_buttons_dict.clear()
		
	var active_quests = QuestManager.active_quests
	if active_quests.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Brak aktywnych zadań."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		quest_list_container.add_child(empty_label)
		return

	var categorized = {
		QuestData.QuestCategory.MAIN_STORY: [],
		QuestData.QuestCategory.SIDE_QUEST: [],
		QuestData.QuestCategory.CONTRACT: [],
		QuestData.QuestCategory.HIDDEN: []
	}
	
	for q_id in active_quests.keys():
		var quest = QuestManager.quest_db[q_id]
		if quest.category != QuestData.QuestCategory.HIDDEN:
			categorized[quest.category].append(quest)
			
	# Kategoryzacja z ładnymi, kolorowymi nagłówkami
	_build_category_section("✦ GŁÓWNE ZADANIA", categorized[QuestData.QuestCategory.MAIN_STORY], Color(1, 0.8, 0.2))
	_build_category_section("✧ ZADANIA POBOCZNE", categorized[QuestData.QuestCategory.SIDE_QUEST], Color(0.6, 0.8, 1))
	_build_category_section("⚔ ZLECENIA", categorized[QuestData.QuestCategory.CONTRACT], Color(0.9, 0.4, 0.4))

func _build_category_section(title: String, quests: Array, color: Color) -> void:
	if quests.is_empty(): return
	var header = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 14)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_child(header)
	quest_list_container.add_child(margin)
	
	for quest in quests:
		var btn = _create_quest_button(quest)
		quest_list_container.add_child(btn)
		_buttons_dict[quest.id] = btn

func _create_quest_button(quest: QuestData) -> Button:
	var btn = Button.new()
	btn.text = "  " + quest.title
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0, 0, 0, 0)
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	style_hover.border_width_left = 4
	style_hover.border_color = Color(0.8, 0.7, 0.4)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	
	btn.pressed.connect(func(): _select_quest(quest.id))
	return btn

func _select_quest(quest_id: StringName) -> void:
	var quest: QuestData = QuestManager.quest_db[quest_id]
	_selected_quest_id = quest_id
	
	if title_label: title_label.text = quest.title
	if description_label: description_label.text = quest.description
	if abandon_button: abandon_button.visible = quest.is_skippable
	
	_build_objectives_text(quest)
	if right_panel: right_panel.show()

func _build_objectives_text(quest: QuestData) -> void:
	if objectives_label == null: return
	var q_data = QuestManager.active_quests[quest.id]
	var stage_idx = q_data["stage"]
	if stage_idx >= quest.stages.size(): return
	
	var stage: QuestStage = quest.stages[stage_idx]
	var text = "[b][color=#dddddd]Cele do wykonania:[/color][/b]\n\n"
	
	if stage.objective_text != "":
		text += "[color=#999999][i]" + stage.objective_text + "[/i][/color]\n\n"
		
	for i in range(stage.objectives.size()):
		var obj: QuestObjective = stage.objectives[i]
		if obj == null: continue
		var current = q_data["progress"].get(i, 0)
		var required = obj.get_required_amount()
		var obj_desc = obj.objective_description
		if obj_desc == "": obj_desc = "Nieznany cel"
		
		if current >= required:
			text += "[color=#66cc66]  ✓ [s]" + obj_desc + " (" + str(current) + "/" + str(required) + ")[/s][/color]\n"
		else:
			text += "[color=#ffffff]  ○ " + obj_desc + " (" + str(current) + "/" + str(required) + ")[/color]\n"
			
	objectives_label.text = text
