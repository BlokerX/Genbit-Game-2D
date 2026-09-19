extends VBoxContainer

@export var action_row_scene: PackedScene 

func _ready() -> void:
	$Header/ResetAllBtn.pressed.connect(_on_category_reset_pressed)
	update_ui()

func update_ui() -> void:
	var list_container = $ScrollContainer/ActionList
	for child in list_container.get_children():
		child.queue_free()
		
	var actions = InputMap.get_actions()
	actions.sort() 
	
	for action in actions:
		if action.begins_with("ui_") or action.begins_with("spatial_"): continue
		
		# Ładujemy rządek z pliku settings_action_row.tscn
		var row = action_row_scene.instantiate()
		list_container.add_child(row)
		row.setup(action)

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Klawiszologii", "Czy zresetować wszystkie ustawienia klawiatury i pada?", func():
			_on_reset_all_pressed()
			menu.set_hover_description("[color=green]Klawisze zostały zresetowane.[/color]")
		)

func _on_reset_all_pressed() -> void:
	var list_container = $ScrollContainer/ActionList
	for child in list_container.get_children():
		if child.has_method("_on_single_reset"):
			child._on_single_reset()

func _get_main_menu() -> Control:
	var curr = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu": return curr
		curr = curr.get_parent()
	return null
