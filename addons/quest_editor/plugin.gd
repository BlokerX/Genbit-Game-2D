@tool
extends EditorPlugin

var viewer_instance: Control

func _enter_tree() -> void:
	viewer_instance = preload("res://addons/quest_editor/quest_editor_main.tscn").instantiate()
	viewer_instance.custom_minimum_size = Vector2(0, 350)
	add_control_to_bottom_panel(viewer_instance, "Edytor Zadań")

func _exit_tree() -> void:
	if viewer_instance:
		remove_control_from_bottom_panel(viewer_instance)
		viewer_instance.queue_free()

func _handles(object: Object) -> bool:
	# Plugin aktywuje się TYLKO, gdy klikniesz na plik typu QuestData
	if object is QuestData:
		return true
	return false

func _edit(object: Object) -> void:
	if object and viewer_instance and is_instance_valid(viewer_instance) and viewer_instance.has_method("load_from_inspector"):
		viewer_instance.load_from_inspector(object)
