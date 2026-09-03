extends Resource
class_name DialogueBranch

@export var graph: DialogueGraph
@export var start_node_id: StringName = &"" # Pozwala nadpisać domyślny początek!
## Warunki aktywacji tego powitania (np. flaga "zabilem_smoka")
@export var conditions: Array[ItemCondition] = []
