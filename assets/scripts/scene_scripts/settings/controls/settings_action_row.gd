extends HBoxContainer

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
	
	var menu = _get_main_menu()
	if menu:
		mouse_entered.connect(func(): menu.set_hover_description("Zmień klawisz przypisany do akcji: [color=orange]" + action.capitalize() + "[/color]"))
		mouse_exited.connect(func(): menu.set_hover_description(""))
	
	_update_buttons()
	
	if bind_btn_kb and not bind_btn_kb.pressed.is_connected(_on_kb_pressed):
		bind_btn_kb.pressed.connect(_on_kb_pressed)
	if bind_btn_pad and not bind_btn_pad.pressed.is_connected(_on_pad_pressed):
		bind_btn_pad.pressed.connect(_on_pad_pressed)

func _get_main_menu() -> Control:
	var curr = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu": return curr
		curr = curr.get_parent()
	return null

func _update_buttons() -> void:
	var events = InputMap.action_get_events(action_name)
	var kb_event = null
	var pad_event = null
	
	for e in events:
		if e is InputEventKey or e is InputEventMouseButton:
			kb_event = e
		elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
			pad_event = e
			
	bind_btn_kb.text = _clean_text(kb_event.as_text()) if kb_event else "Brak"
	bind_btn_pad.text = _clean_text(pad_event.as_text()) if pad_event else "Brak"

# ZAAWANSOWANE CZYSZCZENIE TEKSTU (CZYSTE KLAWISZE)
func _clean_text(text: String) -> String:
	var t = text
	# Natychmiastowe ucięcie słowa Physical i myślników
	t = t.replace(" - Physical", "")
	t = t.replace(" (Physical)", "")
	t = t.replace(" - Fizyczny", "")
	t = t.replace(" (Fizyczny)", "")
	
	# Usunięcie gigantycznych nawiasów od Sony/Xbox/Nintendo
	var regex = RegEx.new()
	regex.compile("\\s*\\(.*?\\)")
	t = regex.sub(t, "", true) 
	
	# Skracanie nazw dla Padów
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
	is_listening = true; listening_device = "KB"
	bind_btn_kb.text = "Naciśnij..."
	bind_btn_kb.release_focus()

func _on_pad_pressed() -> void:
	is_listening = true; listening_device = "PAD"
	bind_btn_pad.text = "Naciśnij..."
	bind_btn_pad.release_focus()

func _input(event: InputEvent) -> void:
	if not is_listening: return
	
	var is_kb = event is InputEventKey or event is InputEventMouseButton
	var is_pad = event is InputEventJoypadButton or event is InputEventJoypadMotion
	
	if event.is_pressed():
		if (listening_device == "KB" and is_kb) or (listening_device == "PAD" and is_pad):
			_replace_event(event)
			is_listening = false
			listening_device = ""
			get_viewport().set_input_as_handled()

func _replace_event(new_event: InputEvent) -> void:
	var events = InputMap.action_get_events(action_name)
	var is_kb_new = new_event is InputEventKey or new_event is InputEventMouseButton
	
	InputMap.action_erase_events(action_name)
	for e in events:
		var is_kb_old = e is InputEventKey or e is InputEventMouseButton
		if is_kb_old != is_kb_new:
			InputMap.action_add_event(action_name, e)
			
	InputMap.action_add_event(action_name, new_event)
	_update_buttons()

func _on_single_reset() -> void:
	InputMap.action_erase_events(action_name)
	var prop = "input/" + action_name
	if ProjectSettings.has_setting(prop):
		var default_dict = ProjectSettings.get_setting(prop)
		if default_dict and default_dict.has("events"):
			for event in default_dict["events"]:
				InputMap.action_add_event(action_name, event)
	_update_buttons()
