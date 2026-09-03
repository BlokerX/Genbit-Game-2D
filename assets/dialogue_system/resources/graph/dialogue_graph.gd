extends Resource
class_name DialogueGraph

@export var start_node_id: StringName = &""

# Słownik: Klucz (StringName) -> Wartość (DialogueNode)
# W edytorze Godot 4.x słowniki w Resource są w pełni obsługiwane i czytelne w Inspektorze
@export var nodes: Dictionary = {}

func get_dialogue_node(node_id: StringName) -> DialogueNode:
	return nodes.get(node_id)
