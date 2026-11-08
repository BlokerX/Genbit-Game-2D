extends CanvasLayer
class_name QuestLogUI

## Sygnał powiadamiający UIController o zamknięciu dziennika (np. przyciskiem X lub klawiszem skrótu).
signal log_closed

const SECONDS_PER_MINUTE: int = 60
const CATEGORY_HEADER_FONT_SIZE: int = 14
const CATEGORY_MARGIN_TOP: int = 10
const CATEGORY_MARGIN_BOTTOM: int = 5
const BUTTON_MARGIN_VERTICAL: int = 8
const BUTTON_BORDER_LEFT_WIDTH: int = 4

const TAB_ACTIVE_COLOR := Color(0.8, 0.7, 0.4)
const TAB_INACTIVE_COLOR := Color(0.4, 0.4, 0.4)
const MAIN_QUEST_COLOR := Color(1.0, 0.8, 0.2)
const SIDE_QUEST_COLOR := Color(0.6, 0.8, 1.0)
const CONTRACT_QUEST_COLOR := Color(0.9, 0.4, 0.4)

@export_group("Referencje UI - Lewy Panel")
@export var tab_active_btn: Button
@export var tab_completed_btn: Button
@export var tab_failed_btn: Button
@export var quest_list_container: Container

@export_group("Referencje UI - Prawy Panel")
@export var right_panel: Control
@export var title_label: Label
@export var description_label: RichTextLabel
@export var objectives_label: RichTextLabel
@export var timer_label: Label
@export var track_button: Button
@export var abandon_button: Button

@export_group("Opcjonalne Elementy")
@export var close_button: Button

enum QuestTab { ACTIVE, COMPLETED, FAILED }
var current_tab: QuestTab = QuestTab.ACTIVE
var _selected_quest_id: StringName = &""
var _buttons_dict: Dictionary = {}

func _ready() -> void:
	layer = GameLayers.UI_HUD 
	hide()
	if right_panel:
		right_panel.hide()

	if abandon_button:
		abandon_button.pressed.connect(_on_abandon_button_pressed)
	if track_button:
		track_button.pressed.connect(_on_track_button_pressed)
	if close_button:
		close_button.pressed.connect(close_log)

	if tab_active_btn:
		tab_active_btn.pressed.connect(func(): switch_tab(QuestTab.ACTIVE))
	if tab_completed_btn:
		tab_completed_btn.pressed.connect(func(): switch_tab(QuestTab.COMPLETED))
	if tab_failed_btn:
		tab_failed_btn.pressed.connect(func(): switch_tab(QuestTab.FAILED))

	QuestManager.quest_started.connect(_on_quest_list_changed)
	QuestManager.quest_updated.connect(_on_quest_list_changed)
	QuestManager.quest_completed.connect(_on_quest_finished)
	QuestManager.quest_failed.connect(_on_quest_finished)
	QuestManager.quest_objective_progressed.connect(_on_objective_progressed)
	QuestManager.quest_tracked_changed.connect(_on_tracked_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleQuestLog"):
		if visible:
			close_log()
		elif not DialogueManager.is_active:
			open_log()
		get_viewport().set_input_as_handled()

	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ToggleInventory")):
		close_log()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible or _selected_quest_id == &"" or current_tab != QuestTab.ACTIVE:
		return

	var active_quests: Dictionary = QuestManager.active_quests
	if active_quests.has(_selected_quest_id):
		var q_data: Dictionary = active_quests[_selected_quest_id]
		if q_data.has("timer") and q_data["timer"] > 0.0:
			var time_left: float = q_data["timer"]
			@warning_ignore("integer_division")
			var mins: int = int(time_left) / SECONDS_PER_MINUTE
			var secs: int = int(time_left) % SECONDS_PER_MINUTE
			timer_label.text = "Pozostały czas: %02d:%02d" % [mins, secs]
			timer_label.show()
		else:
			timer_label.hide()

func switch_tab(tab: QuestTab, keep_selection: bool = false) -> void:
	current_tab = tab

	if tab_active_btn:
		tab_active_btn.add_theme_color_override("font_color", TAB_ACTIVE_COLOR if tab == QuestTab.ACTIVE else TAB_INACTIVE_COLOR)
	if tab_completed_btn:
		tab_completed_btn.add_theme_color_override("font_color", TAB_ACTIVE_COLOR if tab == QuestTab.COMPLETED else TAB_INACTIVE_COLOR)
	if tab_failed_btn:
		tab_failed_btn.add_theme_color_override("font_color", TAB_ACTIVE_COLOR if tab == QuestTab.FAILED else TAB_INACTIVE_COLOR)

	if not keep_selection:
		_selected_quest_id = &""

	_refresh_quest_list()
	right_panel.hide()

	# Automatycznie wybierz wymuszonego questa, ALBO pierwszego na liście
	if _selected_quest_id != &"" and _buttons_dict.has(_selected_quest_id):
		_buttons_dict[_selected_quest_id].emit_signal("pressed")
	elif _buttons_dict.size() > 0:
		_buttons_dict.values()[0].emit_signal("pressed")

func open_log() -> void:
	if visible:
		return
	# Zgłaszamy otwarcie pełnoekranowego menu do UIControllera (który wywoła open_from_menu_request).
	# Jeśli UIController nie obsłużył żądania (np. w scenie testowej), otwieramy dziennik bezpośrednio.
	EventBus.open_fullscreen_menu.emit("QuestLog")
	if not visible:
		_show_log()

func open_from_menu_request() -> void:
	if not visible:
		_show_log()

func _show_log() -> void:
	show()
	get_tree().paused = true
	EventBus.set_menu_state(EventBus.MENU_QUEST_LOG, true)
	switch_tab(current_tab, true)

func close_log() -> void:
	if not visible:
		return
	hide()
	EventBus.set_menu_state(EventBus.MENU_QUEST_LOG, false)
	log_closed.emit()
	if not EventBus.is_any_menu_open():
		get_tree().paused = false

## Funkcja do wymuszania otwarcia konkretnego zadania z zewnątrz (np. po kliknięciu powiadomienia QuestNotificationUI).
func force_open_quest(quest_id: StringName) -> void:
	_selected_quest_id = quest_id
	var target_tab: QuestTab = QuestTab.ACTIVE
	if QuestManager.completed_quests.has(quest_id):
		target_tab = QuestTab.COMPLETED
	elif QuestManager.failed_quests.has(quest_id):
		target_tab = QuestTab.FAILED

	switch_tab(target_tab, true)

# --- ZDARZENIA ---
func _on_quest_list_changed(_quest: QuestData, _stage: int = 0) -> void:
	if visible and current_tab == QuestTab.ACTIVE:
		_refresh_quest_list()

func _on_objective_progressed(quest: QuestData, _obj_idx: int, _count: int) -> void:
	if visible and _selected_quest_id == quest.id and current_tab == QuestTab.ACTIVE:
		_build_objectives_text(quest)

func _on_quest_finished(_quest: QuestData) -> void:
	if visible:
		_refresh_quest_list()

func _on_abandon_button_pressed() -> void:
	if _selected_quest_id != &"":
		QuestManager.abandon_quest(_selected_quest_id)

func _on_track_button_pressed() -> void:
	if _selected_quest_id != &"":
		if QuestManager.tracked_quest_id == _selected_quest_id:
			QuestManager.untrack_quest()
		else:
			QuestManager.track_quest(_selected_quest_id)

func _on_tracked_changed(_quest_id: StringName) -> void:
	if visible and _selected_quest_id != &"":
		_update_track_button()

# --- BUDOWANIE INTERFEJSU ---
func _refresh_quest_list() -> void:
	for child in quest_list_container.get_children():
		child.queue_free()
	_buttons_dict.clear()

	var list_to_process: Array = []
	if current_tab == QuestTab.ACTIVE:
		list_to_process = QuestManager.active_quests.keys()
	elif current_tab == QuestTab.COMPLETED:
		list_to_process = QuestManager.completed_quests
	elif current_tab == QuestTab.FAILED:
		list_to_process = QuestManager.failed_quests

	if list_to_process.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Brak zadań w tej kategorii."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		quest_list_container.add_child(empty_label)
		return

	var categorized: Dictionary = {
		QuestData.QuestCategory.MAIN_STORY: [],
		QuestData.QuestCategory.SIDE_QUEST: [],
		QuestData.QuestCategory.CONTRACT: [],
		QuestData.QuestCategory.HIDDEN: []
	}

	for q_id in list_to_process:
		var quest: QuestData = QuestManager.quest_db[q_id]
		if quest.category != QuestData.QuestCategory.HIDDEN:
			categorized[quest.category].append(quest)

	_build_category_section("GŁÓWNE ZADANIA", categorized[QuestData.QuestCategory.MAIN_STORY], MAIN_QUEST_COLOR)
	_build_category_section("ZADANIA POBOCZNE", categorized[QuestData.QuestCategory.SIDE_QUEST], SIDE_QUEST_COLOR)
	_build_category_section("ZLECENIA", categorized[QuestData.QuestCategory.CONTRACT], CONTRACT_QUEST_COLOR)

func _build_category_section(title: String, quests: Array, color: Color) -> void:
	if quests.is_empty():
		return

	var header: Label = Label.new()
	header.text = title
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", CATEGORY_HEADER_FONT_SIZE)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", CATEGORY_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", CATEGORY_MARGIN_BOTTOM)
	margin.add_child(header)
	quest_list_container.add_child(margin)

	for quest in quests:
		var btn: Button = Button.new()
		btn.text = "  " + quest.title
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# 1. Styl Zwykły (Przezroczysty, z niewidoczną ramką by tekst nie skakał)
		var style_normal: StyleBoxFlat = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style_normal.content_margin_top = BUTTON_MARGIN_VERTICAL
		style_normal.content_margin_bottom = BUTTON_MARGIN_VERTICAL
		style_normal.border_width_left = BUTTON_BORDER_LEFT_WIDTH
		style_normal.border_color = Color(0.0, 0.0, 0.0, 0.0)

		# 2. Styl Najechania Myszką (Szara ramka, delikatne tło)
		var style_hover: StyleBoxFlat = style_normal.duplicate()
		style_hover.bg_color = Color(0.15, 0.15, 0.2, 0.5)
		style_hover.border_color = Color(0.5, 0.5, 0.5, 0.5)

		# 3. Styl Wybranego Zadania (Mocne tło, złota/kolorowa ramka)
		var style_selected: StyleBoxFlat = style_normal.duplicate()
		style_selected.bg_color = Color(0.2, 0.2, 0.25, 0.5)
		style_selected.border_color = color

		btn.set_meta("style_normal", style_normal)
		btn.set_meta("style_hover", style_hover)
		btn.set_meta("style_selected", style_selected)

		btn.pressed.connect(func(): _select_quest(quest.id))
		quest_list_container.add_child(btn)
		_buttons_dict[quest.id] = btn

func _select_quest(quest_id: StringName) -> void:
	var quest: QuestData = QuestManager.quest_db[quest_id]
	_selected_quest_id = quest_id

	if title_label:
		title_label.text = quest.title
	if description_label:
		description_label.text = quest.description

	if current_tab == QuestTab.ACTIVE:
		if abandon_button:
			abandon_button.visible = quest.is_skippable
		if track_button:
			track_button.show()
		if timer_label:
			timer_label.show()
		_update_track_button()
		_build_objectives_text(quest)
	else:
		if abandon_button:
			abandon_button.hide()
		if track_button:
			track_button.hide()
		if timer_label:
			timer_label.hide()
		if objectives_label:
			objectives_label.text = ""

		var summary_text: String = ""
		if current_tab == QuestTab.COMPLETED:
			summary_text = "[color=#ffd700][b]Wniosek:[/b][/color]\n[color=#cccccc][i]" + quest.completed_summary + "[/i][/color]"
		elif current_tab == QuestTab.FAILED:
			summary_text = "[color=#ff5555][b]Porażka:[/b][/color]\n[color=#cccccc][i]" + quest.failed_summary + "[/i][/color]"

		if objectives_label:
			objectives_label.text = summary_text

	if right_panel:
		right_panel.show()

	_update_button_selection()

## Przypisuje podświetlony styl na stałe do wybranego zadania.
func _update_button_selection() -> void:
	for q_id in _buttons_dict.keys():
		var btn: Button = _buttons_dict[q_id]
		if is_instance_valid(btn):
			if q_id == _selected_quest_id:
				btn.add_theme_stylebox_override("normal", btn.get_meta("style_selected"))
				btn.add_theme_stylebox_override("hover", btn.get_meta("style_selected"))
				btn.add_theme_stylebox_override("focus", btn.get_meta("style_selected"))
				btn.add_theme_stylebox_override("pressed", btn.get_meta("style_selected"))
			else:
				btn.add_theme_stylebox_override("normal", btn.get_meta("style_normal"))
				btn.add_theme_stylebox_override("hover", btn.get_meta("style_hover"))
				btn.add_theme_stylebox_override("focus", btn.get_meta("style_hover"))
				btn.add_theme_stylebox_override("pressed", btn.get_meta("style_selected"))

func _update_track_button() -> void:
	if track_button == null:
		return
	if QuestManager.tracked_quest_id == _selected_quest_id:
		track_button.text = "Przestań Śledzić"
		track_button.add_theme_color_override("font_color", Color.GRAY)
	else:
		track_button.text = "Śledź Zadanie"
		track_button.add_theme_color_override("font_color", Color.GOLD)

func _build_objectives_text(quest: QuestData) -> void:
	if objectives_label == null:
		return
	var q_data: Dictionary = QuestManager.active_quests[quest.id]
	var stage_idx: int = q_data["stage"]
	if stage_idx >= quest.stages.size():
		return

	var stage: QuestStage = quest.stages[stage_idx]
	var text: String = "[b][color=#dddddd]Cele do wykonania:[/color][/b]\n\n"
	if stage.objective_text != "":
		text += "[color=#999999][i]" + stage.objective_text + "[/i][/color]\n\n"

	for i in range(stage.objectives.size()):
		var obj: QuestObjective = stage.objectives[i]
		if obj == null:
			continue
		var current: int = q_data["progress"].get(i, 0)
		var required: int = obj.get_required_amount()
		var obj_desc: String = obj.objective_description
		if obj_desc == "":
			obj_desc = "Nieznany cel"

		if current >= required:
			text += "[color=#66cc66]  ✔ [s]" + obj_desc + " (" + str(current) + "/" + str(required) + ")[/s][/color]\n"
		else:
			text += "[color=#ffffff]  • " + obj_desc + " (" + str(current) + "/" + str(required) + ")[/color]\n"

	objectives_label.text = text
