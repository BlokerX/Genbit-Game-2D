extends Node2D # (lub taki typ, jaki ma Twoja scena TestMapGenerateScene)
class_name GameScene

@export var initial_map_scene: PackedScene = preload("res://assets/scenes/maps/level_1_test_map.tscn")
@onready var level_container: Node2D = $LevelContainer

func _ready() -> void:
	# Jeśli kontener map jest pusty na starcie gry, wczytujemy domyślny poziom 1
	if level_container.get_child_count() == 0 and initial_map_scene:
		var map_instance = initial_map_scene.instantiate()
		level_container.add_child(map_instance)
