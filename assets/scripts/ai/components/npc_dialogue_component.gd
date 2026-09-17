extends Node
class_name NPCDialogueComponent

@export_category("Ustawienia Dialogu")
## Zasób grafu dialogowego do odtworzenia
@export var dialogue_graph: DialogueGraph

@onready var interactable: InteractableComponent = $"../InteractableComponent"
@onready var ai_controller: AIController = $"../AIController"

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(interactor: Node) -> void:
	# 1. Jeśli NPC walczy, nie ma czasu na gadanie
	if ai_controller and ai_controller.blackboard.target != null:
		print("NPC: Nie widzisz, że walczę?!")
		return
		
	# 2. Wywołujemy Twój globalny system dialogów z PRAWIDŁOWYMI argumentami
	if dialogue_graph != null and DialogueManager.has_method("start_dialogue"):
		DialogueManager.start_dialogue(dialogue_graph, interactor)
	else:
		push_warning("Brak przypisanego grafu dialogowego w NPCDialogueComponent!")
		
	# 3. Zmuszamy Mózg AI do wejścia w stan konwersacji
	if ai_controller and ai_controller.state_machine:
		var dialogue_state = ai_controller.state_machine.states.get("dialogue")
		if dialogue_state:
			dialogue_state.player_node = interactor
			ai_controller.state_machine.change_state("Dialogue")
