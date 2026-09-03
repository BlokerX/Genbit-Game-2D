extends Node
class_name DialogueComponent

## Lista powitań sprawdzana od góry do dołu. Gra wybierze pierwsze, które spełnia warunki.
@export var branches: Array[DialogueBranch] = []
## Domyślne powitanie, jeśli żadne warunki z gałęzi nie są spełnione
@export var fallback_line: DialogueLine 

func _ready() -> void:
	var interactable = get_parent().get_node_or_null("InteractableComponent")
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	var line_to_play: DialogueLine = fallback_line
	
	# Szukamy od góry do dołu pierwszej gałęzi, której warunki się zgadzają
	for branch in branches:
		if branch == null or branch.start_line == null: 
			continue
			
		var conditions_met = true
		for cond in branch.conditions:
			if cond != null and not cond.check_condition(_interactor, null):
				conditions_met = false
				break
				
		if conditions_met:
			line_to_play = branch.start_line
			break # Znaleźliśmy pasujące powitanie, przerywamy pętlę!
			
	if line_to_play != null:
		DialogueManager.start_dialogue(line_to_play, _interactor)
