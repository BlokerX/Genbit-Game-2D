extends Effect
class_name EmitStoryEventEffect

## Nazwa zdarzenia, na które zareaguje świat (np. "open_boss_door", "spawn_enemies").
@export var event_name: String = ""

func _init() -> void:
	effect_name = "Emit Story Event"

func apply_effect(_target: Node2D) -> bool:
	if event_name != "":
		EventBus.story_event_triggered.emit(event_name)
		print("Dialog: Wyzwolono zdarzenie w świecie -> ", event_name)
		return true
	return false
