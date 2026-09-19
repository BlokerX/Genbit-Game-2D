extends VBoxContainer

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)
	
	_setup_slider($ScaleGlobalRow, "ui_scale_global", GlobalSettings.default_ui_scale_global, "Zmienia globalną skalę całego obrazu 2D i silnika.")
	_setup_slider($ScaleGameRow, "ui_scale_game", GlobalSettings.default_ui_scale_game, "Powiększa ikony i paski tylko podczas właściwej rozgrywki.")
	_setup_slider($ScaleMenuRow, "ui_scale_menu", GlobalSettings.default_ui_scale_menu, "Powiększa elementy takie jak okna craftingu czy ekwipunku.")
	
	_setup_checkbox($HPRow, "show_hp_bar", GlobalSettings.default_show_hp_bar, "Wyświetla aktualny pasek zdrowia bohatera w rogu ekranu.")
	_setup_checkbox($MinimapRow, "show_minimap", GlobalSettings.default_show_minimap, "Pokazuje Minimapę ułatwiającą eksplorację proceduralnego świata.")
	_setup_checkbox($HotbarRow, "show_hotbar", GlobalSettings.default_show_hotbar, "Pokazuje dolny pasek szybkiego dostępu (Sloty 1-9).")
	_setup_checkbox($QuestRow, "show_quest_log", GlobalSettings.default_show_quest_log, "Pokazuje panel śledzenia obecnie wybranego zadania (Questy).")

func update_ui() -> void:
	$ScaleGlobalRow/Slider.value = GlobalSettings.ui_scale_global
	$ScaleGameRow/Slider.value = GlobalSettings.ui_scale_game
	$ScaleMenuRow/Slider.value = GlobalSettings.ui_scale_menu
	$HPRow/CheckBox.button_pressed = GlobalSettings.show_hp_bar
	$MinimapRow/CheckBox.button_pressed = GlobalSettings.show_minimap
	$HotbarRow/CheckBox.button_pressed = GlobalSettings.show_hotbar
	$QuestRow/CheckBox.button_pressed = GlobalSettings.show_quest_log

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Interfejsu", "Czy zresetować wszystkie ustawienia GUI?", func():
			GlobalSettings.reset_category_gui(true)
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano interfejs.[/color]")
		)

func _setup_slider(row: Control, global_var: String, default_val: float, desc: String, is_percent: bool = true) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(85, 0)
	spin.min_value = slider.min_value * 100 if is_percent else slider.min_value
	spin.max_value = slider.max_value * 100 if is_percent else slider.max_value
	spin.step = slider.step * 100 if is_percent else slider.step
	if is_percent: spin.suffix = "%"
	
	val_lbl.get_parent().add_child(spin)
	val_lbl.get_parent().move_child(spin, val_lbl.get_index())
	val_lbl.queue_free()
	
	slider.value = GlobalSettings.get(global_var)
	spin.value = slider.value * 100 if is_percent else slider.value
	
	slider.value_changed.connect(func(val):
		spin.value = val * 100 if is_percent else val
		GlobalSettings.set(global_var, val); GlobalSettings.save_settings()
	)
	spin.value_changed.connect(func(val): slider.value = val / 100.0 if is_percent else val)
	reset_btn.pressed.connect(func(): slider.value = default_val)
	_attach_hover(row, desc)

func _setup_checkbox(row: Control, global_var: String, default_val: bool, desc: String) -> void:
	var check: CheckBox = row.get_node("CheckBox")
	var reset_btn: Button = row.get_node("ResetBtn")
	check.button_pressed = GlobalSettings.get(global_var)
	check.toggled.connect(func(state): GlobalSettings.set(global_var, state); GlobalSettings.save_settings(); EventBus.hud_visibility_requested.emit())
	reset_btn.pressed.connect(func(): check.button_pressed = default_val)
	_attach_hover(row, desc)

func _attach_hover(row: Control, desc: String) -> void:
	var menu = _get_main_menu()
	if menu:
		row.mouse_entered.connect(func(): menu.set_hover_description(desc))
		row.mouse_exited.connect(func(): menu.set_hover_description(""))
		for child in row.get_children():
			if child is Control:
				child.mouse_entered.connect(func(): menu.set_hover_description(desc))

func _get_main_menu() -> Control:
	var curr = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu": return curr
		curr = curr.get_parent()
	return null
