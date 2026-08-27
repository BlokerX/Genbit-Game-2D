extends Control

# Ścieżki dopasowane do Twojego drzewa węzłów
@onready var scroll_container: ScrollContainer = $CenterContainer/MainVBox/ScrollContainer
@onready var action_list: VBoxContainer = $CenterContainer/MainVBox/ScrollContainer/ActionList
@onready var reset_button: Button = $CenterContainer/MainVBox/HBoxContainer/ResetButton
@onready var back_button: Button = $CenterContainer/MainVBox/HBoxContainer/BackButton

var is_listening: bool = false
var action_to_remap: String = ""
var button_to_update: Button = null

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	_build_input_list()

func _build_input_list() -> void:
	for child in action_list.get_children():
		child.queue_free()
		
	var actions = InputMap.get_actions()
	actions.sort() 
	
	for action in actions:
		if action.begins_with("ui_") or action.begins_with("spatial_"):
			continue
			
		# --- NOWOŚĆ: Kontener dodający marginesy ---
		var margin_box = MarginContainer.new()
		margin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Ustawiamy odstępy w pikselach: 20 po bokach, 5 z góry i dołu
		margin_box.add_theme_constant_override("margin_left", 20)
		margin_box.add_theme_constant_override("margin_right", 20)
		margin_box.add_theme_constant_override("margin_top", 5)
		margin_box.add_theme_constant_override("margin_bottom", 5)
			
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
		hbox.add_theme_constant_override("separation", 15) # Odstęp między nazwą, a przyciskami
		
		var label = Label.new()
		label.text = action
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Główny przycisk zmiany klawisza
		var remap_button = Button.new()
		remap_button.custom_minimum_size = Vector2(200, 40) 
		
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			remap_button.text = events[0].as_text()
		else:
			remap_button.text = "Brak"
			
		remap_button.pressed.connect(_on_remap_button_pressed.bind(remap_button, action))
		
		# --- NOWOŚĆ: Przycisk indywidualnego resetu ---
		var single_reset_btn = Button.new()
		single_reset_btn.text = "Reset"
		single_reset_btn.custom_minimum_size = Vector2(70, 40)
		single_reset_btn.pressed.connect(_on_single_reset_pressed.bind(action))
		
		# Składamy elementy do HBoxa
		hbox.add_child(label)
		hbox.add_child(remap_button)
		hbox.add_child(single_reset_btn) 
		
		# Pakujemy HBoxa do kontenera z marginesami i wrzucamy na listę
		margin_box.add_child(hbox)
		action_list.add_child(margin_box)

# --- SYSTEM RESETOWANIA KLAWISZY ---

# Własna funkcja, która resetuje tylko podaną w argumencie akcję
func _reset_action(action: String) -> void:
	InputMap.action_erase_events(action)
	var property_name = "input/" + action
	if ProjectSettings.has_setting(property_name):
		var default_action_dict = ProjectSettings.get_setting(property_name)
		if default_action_dict and default_action_dict.has("events"):
			for event in default_action_dict["events"]:
				InputMap.action_add_event(action, event)

# Globalny reset (Główny przycisk na dole)
func _on_reset_pressed() -> void:
	var actions = InputMap.get_actions()
	for action in actions:
		if action.begins_with("ui_") or action.begins_with("spatial_"):
			continue
		_reset_action(action)
	_build_input_list() # Odświeżamy listę raz po zresetowaniu wszystkich

# Indywidualny reset (Mały przycisk obok klawisza)
func _on_single_reset_pressed(action: String) -> void:
	_reset_action(action)
	_build_input_list() # Odświeżamy listę, by zobaczyć zmianę tego jednego klawisza
# -----------------------------------

func _on_remap_button_pressed(btn: Button, action: String) -> void:
	if is_listening: 
		return 
		
	is_listening = true
	action_to_remap = action
	button_to_update = btn
	
	btn.text = "Wciśnij klawisz..."
	btn.release_focus() 

func _input(event: InputEvent) -> void:
	if not is_listening:
		return
		
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			_assign_new_key(event)
			get_viewport().set_input_as_handled()

func _assign_new_key(event: InputEvent) -> void:
	InputMap.action_erase_events(action_to_remap)
	InputMap.action_add_event(action_to_remap, event)
	
	button_to_update.text = event.as_text()
	
	is_listening = false
	action_to_remap = ""
	button_to_update = null

func _on_back_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("back_from_settings"):
		main_node.back_from_settings()
		
	queue_free()
