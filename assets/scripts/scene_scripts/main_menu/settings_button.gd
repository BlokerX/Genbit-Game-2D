extends Button

@export var settings_scene: PackedScene
var main_scene_node: Node

func _pressed() -> void:
	if settings_scene:
		var scene_instance = settings_scene.instantiate()
		if main_scene_node:
			main_scene_node.add_child(scene_instance)
		else:
			get_tree().current_scene.add_child(scene_instance)
	else:
		push_error("Błąd: Nie przypisano 'settings_scene' w Inspektorze dla: ", name)
