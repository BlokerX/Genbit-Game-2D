extends CanvasLayer
class_name DialogueLogUI

## Prosty przełącznik dostępny w Inspektorze
@export var show_avatars: bool = false

@onready var history_text: RichTextLabel = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/HistoryText
@onready var close_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var scroll_container: ScrollContainer = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer

func _ready() -> void:
	hide()
	close_button.pressed.connect(close_log)
	# Jeśli dialog zniknie w tle, automatycznie zwiń też log
	DialogueManager.dialogue_ended.connect(close_log)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleDialogueLog"):
		if visible:
			# Zawsze pozwalamy zamknąć, jeśli jest otwarte
			close_log()
		elif DialogueManager.is_active:
			# Otwieramy TYLKO wtedy, gdy toczy się rozmowa
			open_log()
			
	if visible and event.is_action_pressed("ui_cancel"):
		close_log()
		get_viewport().set_input_as_handled()

func open_log() -> void:
	show()
	# Zatrzymujemy grę na czas czytania historii
	get_tree().paused = true 
	
	# Budujemy tekst historii używając BBCode
	history_text.text = ""
	
	for entry in DialogueManager.dialogue_history:
		var color_hex = entry["color"].to_html(false)
		var line_text = ""
		
		# --- OPCJONALNY AWATAR ---
		# Korzysta ze zmiennej @export show_avatars zdefiniowanej na górze skryptu
		if show_avatars and entry.has("portrait") and entry["portrait"] != null and entry["portrait"].resource_path != "":
			line_text += "[img=40x40]" + entry["portrait"].resource_path + "[/img] "
		
		# --- IMIĘ MÓWCY ---
		line_text += "[b][color=#" + color_hex + "]" + entry["speaker"] + "[/color][/b]\n"
		
		# --- CAŁY TEKST WCIĘTY W PRAWO ---
		# Tag [indent] sprawi, że każda nowa linija i zawinięcie zyska elegancki odstęp
		line_text += "[indent][color=#cccccc]" + entry["text"] + "[/color][/indent]\n\n"
		
		history_text.text += line_text
	
	# Zabieramy focus klawiatury opcjom dialogowym i dajemy przyciskowi "X"
	close_button.grab_focus()
	
	# Automatyczne przewijanie na sam dół (wymaga odczekania klatki na wygenerowanie tekstu)
	await get_tree().process_frame
	var scrollbar = scroll_container.get_v_scroll_bar()
	if scrollbar:
		scrollbar.value = scrollbar.max_value

func close_log() -> void:
	if not visible:
		return
		
	hide()
	
	if not DialogueManager.is_active:
		get_tree().paused = false
		EventBus.set_menu_state(EventBus.MENU_DIALOGUE, false)
	else:
		# --- NOWE: Jeśli rozmowa dalej trwa, oddajemy focus z powrotem do przycisków dialogu ---
		var dialogue_ui = get_parent().get_node_or_null("DialogueUI")
		if dialogue_ui and dialogue_ui.choices_container.get_child_count() > 0:
			var first_btn = dialogue_ui.choices_container.get_child(0)
			if first_btn is Button:
				first_btn.grab_focus()
