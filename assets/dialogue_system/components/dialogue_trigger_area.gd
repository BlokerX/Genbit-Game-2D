extends Area2D
class_name DialogueTriggerArea

## Lista punktów wejścia sprawdzana od góry do dołu.
@export var dialogue_entries: Array[DialogueEntryPoint] = []
@export var fallback_graph: DialogueGraph
@export var one_shot: bool = true

var _has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# (fragment w _on_interacted / _on_body_entered)
	var graph_to_play: DialogueGraph = fallback_graph
	var override_id: StringName = &""

	for entry in dialogue_entries:
		if entry == null or entry.graph == null: continue
		var conditions_met = true
		for cond in entry.conditions:
			if cond != null and not cond.check_condition(body, null):
				conditions_met = false
				break
		if conditions_met:
			graph_to_play = entry.graph
			override_id = entry	.start_node_id
			break

	if graph_to_play != null:
		DialogueManager.start_dialogue(graph_to_play, body, override_id)
