extends Node

signal dialogue_started(line: DialogueLine)
signal dialogue_ended()

var is_active: bool = false
var current_interactor: Node = null

var dialogue_history: Array[Dictionary] = []

func start_dialogue(line: DialogueLine, interactor: Node) -> void:
	if is_active: 
		return
	is_active = true
	
	current_interactor = interactor
	
	# Całkowite zatrzymanie świata gry (fale wrogów, potwory, pociski)
	get_tree().paused = true 
	
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, true)
	
	dialogue_started.emit(line)

func make_choice(choice: DialogueChoice) -> void:
	if current_interactor and current_interactor.has_method("receive_effect"):
		for effect in choice.consequences:
			if effect != null:
				current_interactor.receive_effect(effect.duplicate(true))

	if choice.next_line != null:
		dialogue_started.emit(choice.next_line)
	else:
		end_dialogue()

func end_dialogue() -> void:
	is_active = false
	
	current_interactor = null
	
	# Odmrożenie świata gry po zakończeniu rozmowy
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
