extends CanvasLayer
class_name DialogueUI

@onready var name_label: Label = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/NameLabel
@onready var portrait_rect: TextureRect = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/PortraitRect
@onready var text_label: RichTextLabel = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/ChoicesContainer

var text_tween: Tween
var current_line: DialogueLine # Dodana zmienna do pamiętania obecnej linii
var _time_in_line: float = 0.0

func _ready() -> void:
	hide()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _process(delta: float) -> void:
	if visible:
		_time_in_line += delta
		
		# TARCZA: Automatycznie oddaje focus do opcji, jeśli gracz zamknął Log padem
		if not DialogueManager.is_log_open and choices_container.get_child_count() > 0:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner == null or not choices_container.is_ancestor_of(focus_owner):
				choices_container.get_child(0).grab_focus()

func _input(event: InputEvent) -> void:
	# TARCZA: Ochrona przed inputem, gdy log jest otwarty (zastępuje awaryjne get_parent)
	if not visible or DialogueManager.is_log_open:
		return
	
	# Blokada czasowa zapobiegająca przypadkowemu pominięciu
	if current_line != null and _time_in_line < current_line.min_skip_time:
		return
	
	var is_mouse_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	
	# Zamień "Interact" na klawisz, którym gracz wchodzi w interakcje
	if event.is_action_pressed("Interact") or event.is_action_pressed("ui_accept") or is_mouse_click:
		if text_tween and text_tween.is_running():
			# Zabijamy animację maszyny do pisania
			text_tween.kill()
			# Odsłaniamy natychmiast cały tekst
			text_label.visible_characters = -1
			# Wywołujemy od razu pokazanie przycisków
			_show_choices(current_line)
			
			# Zapobiegamy przeniknięciu tego kliknięcia na przycisk wyboru
			get_viewport().set_input_as_handled()

func _on_dialogue_started(line: DialogueLine) -> void:
	current_line = line # Zapisujemy linię na wypadek, gdyby gracz pominął tekst
	_time_in_line = 0.0 # Resetujemy zegar linii
	
	# Odczyt danych z obiektu SpeakerData
	if line.speaker != null:
		name_label.text = line.speaker.speaker_name
		name_label.add_theme_color_override("font_color", line.speaker.name_color)
		portrait_rect.texture = line.speaker.portrait
		portrait_rect.visible = (line.speaker.portrait != null)
	else:
		name_label.text = "???"
		portrait_rect.visible = false

	show()
	text_label.text = line.dialogue_text
	text_label.visible_characters = 0
	
	# TARCZA: Bezpieczne, fizyczne wyrywanie węzłów z drzewa (Memory fix)
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()

	if text_tween: 
		text_tween.kill()
	text_tween = create_tween()
	var duration = line.dialogue_text.length() * 0.03
	text_tween.tween_property(text_label, "visible_characters", line.dialogue_text.length(), duration)
	text_tween.finished.connect(_show_choices.bind(line))
	
	# --- ZAKTUALIZOWANY ZAPIS HISTORII ---
	var current_color: Color = Color.WHITE
	var current_portrait: Texture2D = null
	
	if line.speaker != null:
		current_color = line.speaker.name_color
		current_portrait = line.speaker.portrait
		
	DialogueManager.add_to_history(name_label.text, line.dialogue_text, current_color, current_portrait)
	# -------------------------------------
	
	# Zapis historii
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, true)

func _show_choices(line: DialogueLine) -> void:
	# TARCZA: Race Condition Guard. Zapobiega tworzeniu przycisków dwa razy.
	if choices_container.get_child_count() > 0:
		return

	for choice in line.choices:
		if choice == null: continue
		
		var conditions_met = true
		for cond in choice.conditions:
			if cond != null and not cond.check_condition(DialogueManager.current_interactor, null):
				conditions_met = false
				break
				
		if conditions_met:
			var btn = _create_styled_button(choice.choice_text, choice.choice_icon)
			
			btn.pressed.connect(func():
				_disable_all_choices() # TARCZA: Debouncing
				DialogueManager.make_choice(choice)
			)
			choices_container.add_child(btn)
			
	# Opcjonalny przycisk wymuszonego wyjścia z dialogu ---
	if line.allow_cancel:
		var cancel_btn = _create_styled_button(DialogueManager.DEFAULT_END_CONVERSATION_MESSAGE, null)
		cancel_btn.pressed.connect(func():
			_disable_all_choices()
			DialogueManager.end_dialogue()
		)
		choices_container.add_child(cancel_btn)
	
	# Co zrobić, gdy kontener jest całkowicie pusty?
	if choices_container.get_child_count() == 0:
		if line.next_line != null:
			var btn = _create_styled_button(DialogueManager.DEFAULT_SKIP_MESSAGE, null)
			btn.pressed.connect(func(): 
				_disable_all_choices() # TARCZA: Debouncing
				DialogueManager.continue_dialogue(line.next_line)
			)
			choices_container.add_child(btn)
		else:
			var btn = _create_styled_button(DialogueManager.DEFAULT_END_CONVERSATION_MESSAGE, null)
			btn.pressed.connect(func(): 
				_disable_all_choices() # TARCZA: Debouncing
				DialogueManager.end_dialogue()
			)
			choices_container.add_child(btn)
		
	choices_container.get_child(0).grab_focus()

func _disable_all_choices() -> void:
	for child in choices_container.get_children():
		if child is BaseButton: 
			child.disabled = true

func _create_styled_button(btn_text: String, btn_icon: Texture2D) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	if btn_icon != null:
		btn.icon = btn_icon
		btn.expand_icon = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0, 0, 0, 0)
	style_normal.border_width_left = 4
	style_normal.border_color = Color(0.4, 0.4, 0.4, 1)
	style_normal.content_margin_left = 16 
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	style_hover.border_color = Color(1, 1, 1, 1)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	return btn

func _on_dialogue_ended() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	hide()
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, false)
