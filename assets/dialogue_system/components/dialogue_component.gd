extends Node
class_name DialogueComponent

## Lista powitań sprawdzana od góry do dołu. Gra wybierze pierwsze, które spełnia warunki.
@export var branches: Array[DialogueBranch] = []
## Domyślne powitanie, jeśli żadne warunki z gałęzi nie są spełnione
@export var fallback_graph: DialogueGraph 

func _ready() -> void:
	var interactable = get_parent().get_node_or_null("InteractableComponent")
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	# (fragment w _on_interacted / _on_body_entered)
	var graph_to_play: DialogueGraph = fallback_graph
	var override_id: StringName = &""

	for branch in branches:
		if branch == null or branch.graph == null: continue
		var conditions_met = true
		for cond in branch.conditions:
			if cond != null and not cond.check_condition(_interactor, null):
				conditions_met = false
				break
		if conditions_met:
			graph_to_play = branch.graph
			override_id = branch.start_node_id
			break

	if graph_to_play != null:
		DialogueManager.start_dialogue(graph_to_play, _interactor, override_id)
