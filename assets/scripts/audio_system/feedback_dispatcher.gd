class_name FeedbackDispatcher 
extends RefCounted

## Przekazuje oprawę przedmiotu do aktora. Resztą zajmuje się PlayerFeedbackController.
static func play_for_actor(cue: FeedbackCue, actor: Node2D, target: Node2D = null) -> void:
	if cue == null:
		return
	
	if is_instance_valid(actor) and actor.has_method("play_item_feedback"):
		actor.call("play_item_feedback", cue, target)
