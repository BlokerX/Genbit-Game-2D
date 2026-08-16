@tool
extends EditorPlugin

var inspector_plugin

func _enter_tree() -> void:
	inspector_plugin = preload("res://addons/item_system_plugin/item_inspector.gd").new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
