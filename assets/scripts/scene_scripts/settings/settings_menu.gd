extends Control

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

func _ready() -> void:
	if btn_audio: btn_audio.pressed.connect(func(): _switch_tab(panel_audio))
	if btn_graphics: btn_graphics.pressed.connect(func(): _switch_tab(panel_graphics))
	if btn_gui: btn_gui.pressed.connect(func(): _switch_tab(panel_gui))
	if btn_controls: btn_controls.pressed.connect(func(): _switch_tab(panel_controls))
	
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	if btn_global_reset: btn_global_reset.pressed.connect(_request_global_reset)
	
	if confirm_dialog:
		# Podpinamy sygnał zamknięcia tylko RAZ na starcie
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	
	set_hover_description("Wybierz zakładkę z lewej strony, aby dostosować grę.")
	_switch_tab(panel_audio)

func _switch_tab(active_panel: Control) -> void:
	if panel_audio: panel_audio.hide()
	if panel_graphics: panel_graphics.hide()
	if panel_gui: panel_gui.hide()
	if panel_controls: panel_controls.hide()
	
	if active_panel:
		active_panel.show()
		if active_panel.has_method("update_ui"):
			active_panel.update_ui()

func set_hover_description(text: String) -> void:
	if description_label:
		description_label.text = "[center]" + text + "[/center]"

func _request_global_reset() -> void:
	request_confirmation("Pełny Reset", "Czy na pewno chcesz przywrócić WSZYSTKIE ustawienia do wartości domyślnych?", _on_global_reset_confirmed)

func request_confirmation(title: String, text: String, confirm_action: Callable) -> void:
	if not confirm_dialog: return
	confirm_dialog.title = title
	confirm_dialog.dialog_text = text
	# Zapisujemy akcję do wykonania w pamięci, zamiast psuć natywne sygnały okna
	_current_confirm_action = confirm_action
	confirm_dialog.popup_centered()

func _on_confirm_dialog_confirmed() -> void:
	if _current_confirm_action.is_valid():
		_current_confirm_action.call()

func _on_global_reset_confirmed() -> void:
	GlobalSettings.reset_all_to_default(true)
	
	# --- AWARYJNY RESET DEWELOPERSKI (Wymuszony) ---
	if "show_chunk_grid" in GlobalSettings:
		GlobalSettings.show_chunk_grid = GlobalSettings.default_show_chunk_grid
	if "use_developer_camera" in GlobalSettings:
		GlobalSettings.use_developer_camera = GlobalSettings.default_use_developer_camera
	GlobalSettings.save_settings()
	# -----------------------------------------------
	
	if panel_audio and panel_audio.has_method("update_ui"): panel_audio.update_ui()
	if panel_graphics and panel_graphics.has_method("update_ui"): panel_graphics.update_ui()
	if panel_gui and panel_gui.has_method("update_ui"): panel_gui.update_ui()
	if panel_controls and panel_controls.has_method("_on_reset_all_pressed"): panel_controls._on_reset_all_pressed()
	set_hover_description("[color=green]Pomyślnie zresetowano wszystkie ustawienia gry.[/color]")

func _on_back_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("back_from_settings"):
		main_node.back_from_settings()
	queue_free()
