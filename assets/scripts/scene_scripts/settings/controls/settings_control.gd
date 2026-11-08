extends SettingsCategoryPanel
## Zakładka ustawień sterowania generująca wiersze przypisań klawiszy dla wszystkich akcji gry.

@export var action_row_scene: PackedScene 

func _ready() -> void:
	$Header/ResetAllBtn.pressed.connect(_on_category_reset_pressed)
	update_ui()

func update_ui() -> void:
	var list_container: Node = $ScrollContainer/ActionList
	for child in list_container.get_children():
		child.queue_free()

	var actions: Array[StringName] = InputMap.get_actions()
	actions.sort() 

	for action in actions:
		var action_str: String = String(action)
		if action_str.begins_with("ui_") or action_str.begins_with("spatial_"):
			continue

		var row: Node = action_row_scene.instantiate()
		list_container.add_child(row)
		row.call("setup", action_str)

func _on_category_reset_pressed() -> void:
	var menu: Control = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.call(
			"request_confirmation",
			"Reset Klawiszologii",
			"Czy zresetować wszystkie ustawienia klawiatury i pada?",
			func():
				_on_reset_all_pressed()
				menu.call("set_hover_description", "[color=green]Klawisze zostały zresetowane.[/color]")
		)

func _on_reset_all_pressed() -> void:
	GlobalSettings.reset_category_controls(true)
	update_ui()
