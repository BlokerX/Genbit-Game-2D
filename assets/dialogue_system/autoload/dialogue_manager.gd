extends Node

signal dialogue_started(line: DialogueLine)
signal dialogue_ended()

var is_active: bool = false
var current_interactor: Node = null

func start_dialogue(line: DialogueLine, interactor: Node) -> void:
	if is_active: 
		return
	is_active = true
	current_interactor = interactor
	
	# Całkowite zatrzymanie świata gry (fale wrogów, potwory, pociski)
	get_tree().paused = true 
	
	EventBus.ui_state_changed.emit(true) # Blokada ruchu gracza
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
	
	EventBus.ui_state_changed.emit(false) # Odmrożenie wejść gracza
	dialogue_ended.emit()
