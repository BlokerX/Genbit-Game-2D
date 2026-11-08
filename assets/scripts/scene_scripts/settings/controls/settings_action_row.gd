extends HBoxContainer
## Pojedynczy wiersz konfiguracji akcji sterowania (obsługuje niezależny zapis klawiatury/myszy oraz pada).

const JOYPAD_MOTION_DEADZONE_THRESHOLD: float = 0.5

@export var action_label: Label
@export var bind_btn_kb: Button
@export var bind_btn_pad: Button

var action_name: String = ""
var is_listening: bool = false
var listening_device: String = "" # "KB" lub "PAD"

func setup(action: String) -> void:
	action_name = action
	if action_label:
		action_label.text = action.capitalize() 

	var menu: Control = _get_main_menu()
	if menu and menu.has_method("set_hover_description"):
		mouse_entered.connect(func(): menu.call("set_hover_description", "Zmień klawisz przypisany do akcji: [color=orange]" + action.capitalize() + "[/color]"))
		mouse_exited.connect(func(): menu.call("set_hover_description", ""))

	_update_buttons()

	if bind_btn_kb and not bind_btn_kb.pressed.is_connected(_on_kb_pressed):
		bind_btn_kb.pressed.connect(_on_kb_pressed)
	if bind_btn_pad and not bind_btn_pad.pressed.is_connected(_on_pad_pressed):
		bind_btn_pad.pressed.connect(_on_pad_pressed)

	var reset_btn: Button = get_node_or_null("ResetBtn") as Button
	if reset_btn and not reset_btn.pressed.is_connected(_on_single_reset):
		reset_btn.pressed.connect(_on_single_reset)

func _get_main_menu() -> Control:
	var curr: Node = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu" or curr.has_method("set_hover_description"):
			return curr as Control
		curr = curr.get_parent()
	return null

func _update_buttons() -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	var kb_event: InputEvent = null
	var pad_event: InputEvent = null

	for e in events:
		if e is InputEventKey or e is InputEventMouseButton:
			kb_event = e
		elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
			pad_event = e

	if bind_btn_kb:
		bind_btn_kb.text = _clean_text(kb_event.as_text()) if kb_event else "Brak"
	if bind_btn_pad:
		bind_btn_pad.text = _clean_text(pad_event.as_text()) if pad_event else "Brak"

# ZAAWANSOWANE CZYSZCZENIE TEKSTU (CZYSTE NAZWY KLAWISZY I PRZYCISKÓW PADA)
func _clean_text(raw_text: String) -> String:
	var t: String = raw_text

	t = t.replace(" - Physical", "")
	t = t.replace(" (Physical)", "")
	t = t.replace(" - Fizyczny", "")
	t = t.replace(" (Fizyczny)", "")

	var regex: RegEx = RegEx.new()
	regex.compile("\\s*\\(.*?\\)")
	t = regex.sub(t, "", true) 

	t = t.replace("Joypad Motion on Axis 0", "L-Stick Lewo/Prawo")
	t = t.replace("Joypad Motion on Axis 1", "L-Stick Góra/Dół")
	t = t.replace("Joypad Motion on Axis 2", "R-Stick Lewo/Prawo")
	t = t.replace("Joypad Motion on Axis 3", "R-Stick Góra/Dół")
	t = t.replace("Joypad Motion on Axis 4", "L2 (Trigger)")
	t = t.replace("Joypad Motion on Axis 5", "R2 (Trigger)")

	t = t.replace("Joypad Button 0", "A / Krzyżyk")
	t = t.replace("Joypad Button 1", "B / Kółko")
	t = t.replace("Joypad Button 2", "X / Kwadrat")
	t = t.replace("Joypad Button 3", "Y / Trójkąt")
	t = t.replace("Joypad Button 4", "Back / Select")
	t = t.replace("Joypad Button 6", "Start / Options")
	t = t.replace("Joypad Button 11", "D-pad Góra")
	t = t.replace("Joypad Button 12", "D-pad Dół")
	t = t.replace("Joypad Button 13", "D-pad Lewo")
	t = t.replace("Joypad Button 14", "D-pad Prawo")

	t = t.replace("Joypad Button", "Pad Btn")
	t = t.replace("Joypad Motion on Axis", "Pad Oś")

	return t.strip_edges()

func _on_kb_pressed() -> void:
	is_listening = true
	listening_device = "KB"
	bind_btn_kb.text = "Naciśnij..."
	bind_btn_kb.release_focus()

func _on_pad_pressed() -> void:
	is_listening = true
	listening_device = "PAD"
	bind_btn_pad.text = "Naciśnij..."
	bind_btn_pad.release_focus()

func _input(event: InputEvent) -> void:
	if not is_listening:
		return

	var is_kb: bool = event is InputEventKey or event is InputEventMouseButton
	var is_pad: bool = event is InputEventJoypadButton or (
		event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) >= JOYPAD_MOTION_DEADZONE_THRESHOLD
	)

	if event.is_pressed() or is_pad:
		if (listening_device == "KB" and is_kb) or (listening_device == "PAD" and is_pad):
			_replace_event(event)
			is_listening = false
			listening_device = ""
			get_viewport().set_input_as_handled()

func _replace_event(new_event: InputEvent) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	var is_kb_new: bool = new_event is InputEventKey or new_event is InputEventMouseButton

	InputMap.action_erase_events(action_name)

	for e in events:
		var is_kb_old: bool = e is InputEventKey or e is InputEventMouseButton
		if is_kb_old != is_kb_new:
			InputMap.action_add_event(action_name, e)

	InputMap.action_add_event(action_name, new_event)
	# Trwały zapis nowego przypisania klawisza w pliku user://settings.cfg!
	GlobalSettings.save_settings()
	_update_buttons()

func _on_single_reset() -> void:
	GlobalSettings.reset_single_action_to_default(action_name, true)
	_update_buttons()
