extends Node

const DEFAULT_SKIP_MESSAGE : String = "..."
const DEFAULT_END_CONVERSATION_MESSAGE : String = "Do zobaczenia!"

# ZMIANA: Wysyłamy DialogueNode zamiast starego DialogueLine
signal dialogue_started(node: DialogueNode) 
signal dialogue_ended()

var is_active: bool = false
var is_log_open: bool = false
var current_interactor: Node = null
var dialogue_history: Array[Dictionary] = []
var default_player_speaker: SpeakerData = null

# NOWE ZMIENNE: Zarządzanie grafem
var current_graph: DialogueGraph = null
var current_node_id: StringName = &""

func _ready() -> void:
	var path = "res://assets/dialogue_system/data/speakers/player_speaker.tres"
	if ResourceLoader.exists(path):
		default_player_speaker = load(path)

# ZMIANA: Przyjmujemy DialogueGraph i opcjonalne ID startowe
func start_dialogue(graph: DialogueGraph, interactor: Node, start_id: StringName = &"") -> void:
	if is_active or graph == null: 
		return
	is_active = true
	current_interactor = interactor
	current_graph = graph
	get_tree().paused = true 
	EventBus.set_menu_state(EventBus.MENU_DIALOGUE, true)
	
	# Określenie, od którego węzła zacząć
	var first_id = start_id if start_id != &"" else graph.start_node_id
	go_to_node(first_id)

func go_to_node(node_id: StringName) -> void:
	if current_graph == null or not current_graph.nodes.has(node_id):
		push_warning("Błąd: Nie znaleziono węzła '" + str(node_id) + "' w grafie!")
		end_dialogue()
		return
		
	current_node_id = node_id
	var node: DialogueNode = current_graph.nodes[node_id]
	
	var visit_key = str(current_graph.resource_path) + "_" + str(node_id)
	DialogueState.increment_counter(visit_key)
	
	# ROZWIDLENIE LOGIKI:
	if node.is_auto_advance():
		# Węzeł automatyczny (np. Condition, Action, Random)
		var next_node_id = node.process_auto_logic(current_interactor)
		if next_node_id != &"":
			go_to_node(next_node_id) # Natychmiastowy przeskok (rekurencja)
		else:
			end_dialogue()
	else:
		# Węzeł interaktywny (wymaga UI)
		dialogue_started.emit(node)

# ZMIANA: Przyjmuje Connection, wywołuje efekty i wykonuje skok
func make_choice(connection: DialogueConnection) -> void:
	if connection.log_choice and connection.text != "" and connection.text != DEFAULT_SKIP_MESSAGE:
		var s_name = "Gracz"
		var s_color = Color(0.8, 0.8, 0.8, 1.0)
		var s_port = null
		if default_player_speaker != null:
			s_name = default_player_speaker.speaker_name
			s_color = default_player_speaker.name_color
			s_port = default_player_speaker.portrait
		if connection.custom_speaker != null:
			s_name = connection.custom_speaker.speaker_name
			s_color = connection.custom_speaker.name_color
			s_port = connection.custom_speaker.portrait
		add_to_history(s_name, connection.text, s_color, s_port)
		
	if current_interactor and current_interactor.has_method("receive_effect"):
		for effect in connection.consequences:
			if effect != null:
				current_interactor.receive_effect(effect.duplicate(true))
	
	# Skok do kolejnego węzła!
	if connection.target_id != &"":
		go_to_node(connection.target_id)
	else:
		end_dialogue()

func end_dialogue(keep_paused: bool = false) -> void:
	is_active = false
	current_interactor = null
	current_graph = null
	current_node_id = &""
	if not keep_paused:
		get_tree().paused = false
		EventBus.set_menu_state(EventBus.MENU_DIALOGUE, false)
	dialogue_ended.emit()

func add_to_history(speaker_name: String, text: String, color: Color = Color.WHITE, portrait: Texture2D = null) -> void:
	dialogue_history.append({
		"speaker": speaker_name,
		"text": text,
		"color": color,
		"portrait": portrait
	})
	if dialogue_history.size() > 50:
		dialogue_history.pop_front()
