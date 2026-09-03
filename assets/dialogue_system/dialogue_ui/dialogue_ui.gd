extends CanvasLayer
class_name DialogueUI

@onready var name_label: Label = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/NameLabel
@onready var portrait_rect: TextureRect = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/PortraitRect
@onready var text_label: RichTextLabel = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/DialogueBox/InnerMargin/HBoxContainer/VBoxContainer/ChoicesContainer

var text_tween: Tween
var current_node: DialogueNode
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
	if current_node != null and _time_in_line < current_node.min_skip_time:
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
			_show_choices(current_node)
			
			# Zapobiegamy przeniknięciu tego kliknięcia na przycisk wyboru
			get_viewport().set_input_as_handled()

func _on_dialogue_started(node: DialogueNode) -> void:
	current_node = node
	_time_in_line = 0.0 
	
	if node.speaker != null:
		name_label.text = node.speaker.speaker_name
		name_label.add_theme_color_override("font_color", node.speaker.name_color)
		portrait_rect.texture = node.speaker.portrait
		portrait_rect.visible = (node.speaker.portrait != null)
	else:
		name_label.text = "???"
		portrait_rect.visible = false
		
	show()
	text_label.text = node.dialogue_text
	text_label.visible_characters = 0
	
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
		
	if text_tween: text_tween.kill()
	text_tween = create_tween()
	var duration = node.dialogue_text.length() * 0.03
	text_tween.tween_property(text_label, "visible_characters", node.dialogue_text.length(), duration)
	text_tween.finished.connect(_show_choices.bind(node))
	
	var current_color: Color = Color.WHITE
	var current_portrait: Texture2D = null
	if node.speaker != null:
		current_color = node.speaker.name_color
		current_portrait = node.speaker.portrait
	DialogueManager.add_to_history(name_label.text, node.dialogue_text, current_color, current_portrait)
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, true)

func _show_choices(node: DialogueNode) -> void:
	if choices_container.get_child_count() > 0: return
	
	# ZMIANA: iterujemy po "outputs" zamiast "choices"
	for connection in node.outputs:
		if connection == null: continue
		var conditions_met = true
		for cond in connection.conditions:
			if cond != null and not cond.check_condition(DialogueManager.current_interactor, null):
				conditions_met = false
				break
				
		if conditions_met:
			# Jeżeli tekst jest pusty, traktujemy to jako ciche przejście (dawne 'next_line')
			var btn_text = connection.text if connection.text != "" else DialogueManager.DEFAULT_SKIP_MESSAGE
			var btn = _create_styled_button(btn_text, connection.choice_icon)
			
			btn.pressed.connect(func():
				_disable_all_choices()
				DialogueManager.make_choice(connection)
			)
			choices_container.add_child(btn)
			
	if node.allow_cancel:
		var cancel_btn = _create_styled_button(DialogueManager.DEFAULT_END_CONVERSATION_MESSAGE, null)
		cancel_btn.pressed.connect(func():
			_disable_all_choices()
			DialogueManager.end_dialogue()
		)
		choices_container.add_child(cancel_btn)
		
	if choices_container.get_child_count() == 0:
		var btn = _create_styled_button(DialogueManager.DEFAULT_END_CONVERSATION_MESSAGE, null)
		btn.pressed.connect(func(): 
			_disable_all_choices()
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
