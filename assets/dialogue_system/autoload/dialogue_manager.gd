extends Node

const DEFAULT_SKIP_MESSAGE : String = "..."
const DEFAULT_END_CONVERSATION_MESSAGE : String = "Do zobaczenia!"

signal dialogue_started(line: DialogueLine)
signal dialogue_ended()

var is_active: bool = false
var is_log_open: bool = false # TARCZA: Globalny stan logu
var current_interactor: Node = null

var dialogue_history: Array[Dictionary] = []

var default_player_speaker: SpeakerData = null

func _ready() -> void:
	# TARCZA: Miękkie ładowanie chroni przed crashem, jeśli plik nie istnieje
	var path = "res://assets/dialogue_system/data/speakers/player_speaker.tres"
	if ResourceLoader.exists(path):
		default_player_speaker = load(path)

func start_dialogue(line: DialogueLine, interactor: Node) -> void:
	if is_active: 
		return
	is_active = true
	
	current_interactor = interactor
	
	# Całkowite zatrzymanie świata gry (fale wrogów, potwory, pociski)
	get_tree().paused = true 
	
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, true)
	
	dialogue_started.emit(line)

func continue_dialogue(next_line: DialogueLine) -> void:
	if next_line != null:
		dialogue_started.emit(next_line)
	else:
		end_dialogue()

func make_choice(choice: DialogueChoice) -> void:
	# Zapis do historii (tylko znaczące wybory)
	if choice.log_choice and choice.choice_text != "" and choice.choice_text != DEFAULT_SKIP_MESSAGE:
		var s_name = "Gracz"
		var s_color = Color(0.8, 0.8, 0.8, 1.0)
		var s_port = null
		
		if default_player_speaker != null:
			s_name = default_player_speaker.speaker_name
			s_color = default_player_speaker.name_color
			s_port = default_player_speaker.portrait
			
		if choice.custom_speaker != null:
			s_name = choice.custom_speaker.speaker_name
			s_color = choice.custom_speaker.name_color
			s_port = choice.custom_speaker.portrait
			
		add_to_history(s_name, choice.choice_text, s_color, s_port)

	if current_interactor and current_interactor.has_method("receive_effect"):
		for effect in choice.consequences:
			if effect != null:
				current_interactor.receive_effect(effect.duplicate(true))

	continue_dialogue(choice.next_line)

func end_dialogue(keep_paused: bool = false) -> void:
	is_active = false
	
	current_interactor = null
	
	# Zapobiega wyciekowi 1 klatki fizyki przy otwieraniu sklepu/ekwipunku
	if not keep_paused:
		get_tree().paused = false
	
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, false)
	dialogue_ended.emit()

func add_to_history(speaker_name: String, text: String, color: Color = Color.WHITE, portrait: Texture2D = null) -> void:
	dialogue_history.append({
		"speaker": speaker_name,
		"text": text,
		"color": color,
		"portrait": portrait # <- Dodane zapamiętywanie obrazka
	})
	
	if dialogue_history.size() > 50:
		dialogue_history.pop_front()
