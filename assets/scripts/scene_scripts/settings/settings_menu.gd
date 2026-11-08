extends Control
## Główne okno menu ustawień zarządzające zakładkami (Audio, Grafika, GUI, Sterowanie) oraz oknem potwierdzeń.

const SETTINGS_BUTTON_FEEDBACK: FeedbackCue = preload(
	"res://assets/data/feedback/ui/settings_button.tres"
)

@export_category("Nawigacja")
@export var btn_audio: Button
@export var btn_graphics: Button
@export var btn_gui: Button
@export var btn_controls: Button
@export var btn_back: Button
@export var btn_global_reset: Button

@export_category("Panele")
@export var panel_audio: Control
@export var panel_graphics: Control
@export var panel_gui: Control
@export var panel_controls: Control

@export_category("Dialogi i Opisy")
@export var description_label: RichTextLabel
@export var confirm_dialog: ConfirmationDialog

var _current_confirm_action: Callable
var _all_tabs: Array[Control] = []

func _ready() -> void:
	_all_tabs = [panel_audio, panel_graphics, panel_gui, panel_controls]
	_bind_button_feedback(self)

	if btn_audio:
		btn_audio.pressed.connect(func(): _switch_tab(panel_audio))
	if btn_graphics:
		btn_graphics.pressed.connect(func(): _switch_tab(panel_graphics))
	if btn_gui:
		btn_gui.pressed.connect(func(): _switch_tab(panel_gui))
	if btn_controls:
		btn_controls.pressed.connect(func(): _switch_tab(panel_controls))

	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_global_reset:
		btn_global_reset.pressed.connect(_request_global_reset)

	if confirm_dialog:
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)

	set_hover_description("Wybierz zakładkę z lewej strony, aby dostosować grę.")
	_switch_tab(panel_audio)

func _bind_button_feedback(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton and not (child as BaseButton).button_down.is_connected(_play_button_feedback):
			(child as BaseButton).button_down.connect(_play_button_feedback)
		_bind_button_feedback(child)

func _play_button_feedback() -> void:
	GameFeedback.play_cue(SETTINGS_BUTTON_FEEDBACK)

func _switch_tab(active_panel: Control) -> void:
	for tab in _all_tabs:
		if tab != null:
			tab.hide()

	if active_panel != null:
		active_panel.show()
		if active_panel.has_method("update_ui"):
			active_panel.call("update_ui")

func set_hover_description(text: String) -> void:
	if description_label:
		description_label.text = "[center]" + text + "[/center]"

func _request_global_reset() -> void:
	request_confirmation(
		"Pełny Reset",
		"Czy na pewno chcesz przywrócić WSZYSTKIE ustawienia do wartości domyślnych?",
		_on_global_reset_confirmed
	)

func request_confirmation(title: String, text: String, confirm_action: Callable) -> void:
	if not confirm_dialog:
		return
	confirm_dialog.title = title
	confirm_dialog.dialog_text = text
	_current_confirm_action = confirm_action
	confirm_dialog.popup_centered()

func _on_confirm_dialog_confirmed() -> void:
	if _current_confirm_action.is_valid():
		_current_confirm_action.call()

func _on_global_reset_confirmed() -> void:
	GlobalSettings.reset_all_to_default(true)

	for tab in _all_tabs:
		if tab != null and tab.has_method("update_ui"):
			tab.call("update_ui")

	set_hover_description("[color=green]Pomyślnie zresetowano wszystkie ustawienia gry.[/color]")

func _on_back_pressed() -> void:
	var main_node: Node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("back_from_settings"):
		main_node.call("back_from_settings")
	queue_free()
