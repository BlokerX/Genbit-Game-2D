@tool
extends EditorPlugin

var viewer_instance: Control

func _enter_tree() -> void:
	viewer_instance = preload("res://addons/dialogue_viewer/dialogue_viewer_main.tscn").instantiate()
	viewer_instance.custom_minimum_size = Vector2(0, 350)
	add_control_to_bottom_panel(viewer_instance, "Graf Dialogu")

func _exit_tree() -> void:
	if viewer_instance:
		remove_control_from_bottom_panel(viewer_instance)
		viewer_instance.queue_free()

# Nasłuchiwanie kliknięć w Inspektorze (zmieniony warunek!)
func _handles(object: Object) -> bool:
	if object is Resource and object.get_script() != null:
		var script_name = object.get_script().resource_path.get_file()
		# Reaguje na każdy plik, który w nazwie skryptu ma "dialogue" lub "speaker"
		if "dialogue" in script_name or "speaker" in script_name:
			return true
	return false

# Akcja po kliknięciu prawidłowego pliku
func _edit(object: Object) -> void:
	if object and viewer_instance and viewer_instance.has_method("load_from_inspector"):
		viewer_instance.load_from_inspector(object)
		make_bottom_panel_item_visible(viewer_instance)
