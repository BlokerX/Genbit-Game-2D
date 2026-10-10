class_name FeedbackDispatcher
extends RefCounted

## Przekazuje oprawę przedmiotu do aktora, który odpowiada za jej odtworzenie.
static func play_for_actor(
	cue: FeedbackCue,
	actor: Node2D,
	target: Node2D
) -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("play_item_feedback"):
		actor.call("play_item_feedback", cue, target)
