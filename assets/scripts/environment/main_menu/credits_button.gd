extends Button

var main_scene_node:Node

func _pressed() -> void:
	var scene:PackedScene = load("res://assets/scenes/credits.tscn")
	var scene_instance = scene.instantiate()
	main_scene_node.add_child(scene_instance)
