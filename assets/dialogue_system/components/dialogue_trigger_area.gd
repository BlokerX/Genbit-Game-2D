extends Area2D
class_name DialogueTriggerArea

## Lista powitań sprawdzana od góry do dołu.
@export var branches: Array[DialogueBranch] = []
@export var fallback_line: DialogueLine
@export var one_shot: bool = true

var _has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _has_triggered and one_shot:
		return
		
	if body.is_in_group("Player"):
		var line_to_play: DialogueLine = fallback_line
		
		for branch in branches:
			if branch == null or branch.start_line == null: 
				continue
				
			var conditions_met = true
			for cond in branch.conditions:
				if cond != null and not cond.check_condition(body, null):
					conditions_met = false
					break
					
			if conditions_met:
				line_to_play = branch.start_line
				break
				
		if line_to_play != null:
			_has_triggered = true
			DialogueManager.start_dialogue(line_to_play, body)
		else:
			push_warning("DialogueTriggerArea nie znalazło poprawnej linii dialogowej!")
