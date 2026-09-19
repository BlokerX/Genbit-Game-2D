extends VBoxContainer

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)
	
	_setup_option($ModeRow, "display_mode", GlobalSettings.default_display_mode, "W Oknie: Łatwe przełączanie. Pełny Ekran: Lepsza wydajność.")
	_setup_checkbox($VsyncRow, "vsync_enabled", GlobalSettings.default_vsync_enabled, "Synchronizuje klatki gry z monitorem. Eliminuje 'rwanie' obrazu (Tearing).")
	
	_setup_slider($BrightnessRow, "brightness", GlobalSettings.default_brightness, "Reguluje jasność całego obrazu. Opcja użyteczna w ciemnych lochach.")
	_setup_slider($ContrastRow, "contrast", GlobalSettings.default_contrast, "Dostosowuje kontrast dla lepszej widoczności krawędzi i tekstur.")
	_setup_slider($SaturationRow, "saturation", GlobalSettings.default_saturation, "Intensywność barw. Możesz zredukować, by gra była mroczniejsza i wyblakła.")

func update_ui() -> void:
	$ModeRow/OptionButton.select(GlobalSettings.display_mode)
	$VsyncRow/CheckBox.button_pressed = GlobalSettings.vsync_enabled
	$BrightnessRow/Slider.value = GlobalSettings.brightness
	$ContrastRow/Slider.value = GlobalSettings.contrast
	$SaturationRow/Slider.value = GlobalSettings.saturation

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Grafiki", "Czy zresetować wszystkie ustawienia graficzne?", func():
			GlobalSettings.reset_category_graphics(true)
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano grafikę.[/color]")
		)

func _setup_option(row: Control, global_var: String, default_val: int, desc: String) -> void:
	var opt: OptionButton = row.get_node("OptionButton")
	var reset_btn: Button = row.get_node("ResetBtn")
	if opt.item_count == 0:
		opt.add_item("W Oknie", DisplayServer.WINDOW_MODE_WINDOWED)
		opt.add_item("Pełny Ekran", DisplayServer.WINDOW_MODE_FULLSCREEN)
		opt.add_item("Bez Ramki", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	opt.select(GlobalSettings.get(global_var))
	opt.item_selected.connect(func(idx): GlobalSettings.set(global_var, opt.get_item_id(idx)); GlobalSettings.save_settings())
	reset_btn.pressed.connect(func(): opt.select(default_val); opt.item_selected.emit(default_val))
	_attach_hover(row, desc)

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
	check.toggled.connect(func(state): GlobalSettings.set(global_var, state); GlobalSettings.save_settings())
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
