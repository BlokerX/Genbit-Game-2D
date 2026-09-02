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

func _input(event: InputEvent) -> void:
	# Ignorujemy inputy, jeśli okno jest ukryte
	if not visible:
		return
	
	# --- NOWE ZABEZPIECZENIE: Zablokuj input, jeśli otwarty jest log historii ---
	var log_ui = get_parent().get_node_or_null("DialogueLogUI")
	if log_ui and log_ui.visible:
		return
	# ----------------------------------------------------------------------------
	
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
	
	for child in choices_container.get_children():
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
	for choice in line.choices:
		if choice == null: continue
		
		var conditions_met = true
		for cond in choice.conditions:
			if cond != null and not cond.check_condition(DialogueManager.current_interactor, null):
				conditions_met = false
				break
				
		if conditions_met:
			var btn = Button.new()
			btn.text = choice.choice_text
			
			# Ikona opcji dialogowej
			if choice.choice_icon != null:
				btn.icon = choice.choice_icon
				btn.expand_icon = true
			
			# Wyrównanie tekstu przycisku ściśle do lewej strony
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			# Styl dla stanu spoczynkowego (szary znacznik z lewej + odstęp tekstu)
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(0, 0, 0, 0)
			style_normal.border_width_left = 4
			style_normal.border_width_top = 0
			style_normal.border_width_right = 0
			style_normal.border_width_bottom = 0
			style_normal.border_color = Color(0.4, 0.4, 0.4, 1)
			# Kluczowe: Odsunięcie tekstu w prawo od paska krawędziowego
			style_normal.content_margin_left = 16 
			style_normal.content_margin_top = 4
			style_normal.content_margin_bottom = 4
			
			# Styl po najechaniu (podświetlenie)
			var style_hover = StyleBoxFlat.new()
			style_hover.bg_color = Color(0.2, 0.2, 0.2, 0.5)
			style_hover.border_width_left = 4
			style_hover.border_width_top = 0
			style_hover.border_width_right = 0
			style_hover.border_width_bottom = 0
			style_hover.border_color = Color(1, 1, 1, 1)
			# Ten sam lewy margines, żeby tekst nie skakał przy najechaniu
			style_hover.content_margin_left = 16 
			style_hover.content_margin_top = 4
			style_hover.content_margin_bottom = 4
			
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("focus", style_hover)
			btn.add_theme_stylebox_override("pressed", style_hover)
			
			btn.pressed.connect(func(): DialogueManager.make_choice(choice))
			choices_container.add_child(btn)
			
	if choices_container.get_child_count() == 0:
		var btn = Button.new()
		btn.text = "Zakończ."
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# (Tu skopiuj powtórzony styl przycisku z poprzednich kroków)
		btn.pressed.connect(func(): DialogueManager.end_dialogue())
		choices_container.add_child(btn)
		
	choices_container.get_child(0).grab_focus()

func _on_dialogue_ended() -> void:
	# Uwolnienie focusu przed ukryciem, aby gra odzyskała czyste sterowanie padem
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	hide()
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, false)
