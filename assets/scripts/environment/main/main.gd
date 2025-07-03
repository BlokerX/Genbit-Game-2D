extends Node

func _ready() -> void:
	# Loading scene
	var scene:PackedScene = load("res://assets/scenes/main_menu.tscn")
	# Instancing of the scene
	var scene_instance = scene.instantiate()
	# Adds main_menu as child of the Main node
	self.add_child(scene_instance)

func start_game(scene_to_remove : Node) -> void:
	# Loading demo game scene
	var scene:PackedScene = load("res://assets/scenes/demo_movement.tscn")
	# Instancing of the scene
	var scene_instance = scene.instantiate()
	# Adds scene_instance as child of the Main node
	self.add_child(scene_instance)
	# Remove main_menu from SceneTree if not null
	if scene_to_remove != null :
		scene_to_remove.queue_free()
