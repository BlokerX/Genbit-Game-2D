extends VBoxContainer

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)
	
	_setup_cycle_btn($ModeRow, "display_mode", GlobalSettings.default_display_mode, 
		[{"label": "W Oknie", "value": DisplayServer.WINDOW_MODE_WINDOWED}, 
		 {"label": "Pełny Ekran", "value": DisplayServer.WINDOW_MODE_FULLSCREEN}, 
		 {"label": "Bez Ramki", "value": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN}], 
		 "W Oknie: Łatwe przełączanie. Pełny Ekran: Lepsza wydajność.")
		 
	_setup_toggle_btn($VsyncRow, "vsync_enabled", GlobalSettings.default_vsync_enabled, "Synchronizuje klatki gry z monitorem. Eliminuje 'rwanie' obrazu (Tearing).")
	
	_setup_slider($BrightnessRow, "brightness", GlobalSettings.default_brightness, "Reguluje jasność całego obrazu. Opcja użyteczna w ciemnych lochach.")
	_setup_slider($ContrastRow, "contrast", GlobalSettings.default_contrast, "Dostosowuje kontrast dla lepszej widoczności krawędzi i tekstur.")
	_setup_slider($SaturationRow, "saturation", GlobalSettings.default_saturation, "Intensywność barw. Możesz zredukować, by gra była mroczniejsza i wyblakła.")

func update_ui() -> void:
	$BrightnessRow/Slider.value = GlobalSettings.brightness
	$ContrastRow/Slider.value = GlobalSettings.contrast
	$SaturationRow/Slider.value = GlobalSettings.saturation
	
	_update_toggle_btn($VsyncRow/ToggleBtn, GlobalSettings.vsync_enabled)
	# Dla Cycle Button symulujemy wciśnięcie, by odświeżyć tekst
	var cur_mode = GlobalSettings.display_mode
	var btn = $ModeRow/ToggleBtn
	if cur_mode == DisplayServer.WINDOW_MODE_WINDOWED: btn.text = "W Oknie"
	elif cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN: btn.text = "Pełny Ekran"
	else: btn.text = "Bez Ramki"

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Grafiki", "Czy zresetować wszystkie ustawienia graficzne?", func():
			GlobalSettings.reset_category_graphics(true)
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano grafikę.[/color]")
		)

func _setup_cycle_btn(row: Control, global_var: String, default_val: int, options: Array, desc: String) -> void:
	var btn: Button = row.get_node("ToggleBtn")
	var reset_btn: Button = row.get_node("ResetBtn")
	
	var update_text = func():
		var cur = GlobalSettings.get(global_var)
		for opt in options:
			if opt["value"] == cur:
				btn.text = opt["label"]
				return
		btn.text = "Nieznane"
	
	update_text.call()
	
	btn.pressed.connect(func():
		var cur = GlobalSettings.get(global_var)
		var idx = 0
		for i in range(options.size()):
			if options[i]["value"] == cur:
				idx = i
				break
		idx = (idx + 1) % options.size()
		GlobalSettings.set(global_var, options[idx]["value"])
		GlobalSettings.save_settings()
		update_text.call()
	)
	
	reset_btn.pressed.connect(func():
		GlobalSettings.set(global_var, default_val)
		GlobalSettings.save_settings()
		update_text.call()
	)
	_attach_hover(row, desc)

func _setup_slider(row: Control, global_var: String, default_val: float, desc: String) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	slider.step = 0.01 
	
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(85, 0)
	spin.min_value = slider.min_value * 100 
	spin.max_value = slider.max_value * 100 
	spin.step = 1.0 
	spin.suffix = "%"
	
	val_lbl.get_parent().add_child(spin)
	val_lbl.get_parent().move_child(spin, val_lbl.get_index())
	val_lbl.queue_free()
	
	slider.value = GlobalSettings.get(global_var)
	spin.value = slider.value * 100 
	
	slider.value_changed.connect(func(val):
		spin.value = val * 100 
		GlobalSettings.set(global_var, val); GlobalSettings.save_settings()
	)
	spin.value_changed.connect(func(val): slider.value = val / 100.0)
	reset_btn.pressed.connect(func(): slider.value = default_val)
	_attach_hover(row, desc)

func _setup_toggle_btn(row: Control, global_var: String, default_val: bool, desc: String) -> void:
	var btn: Button = row.get_node("ToggleBtn")
	var reset_btn: Button = row.get_node("ResetBtn")
	_update_toggle_btn(btn, GlobalSettings.get(global_var))
	
	btn.pressed.connect(func():
		var new_val = not GlobalSettings.get(global_var)
		GlobalSettings.set(global_var, new_val)
		GlobalSettings.save_settings()
		_update_toggle_btn(btn, new_val)
	)
	reset_btn.pressed.connect(func():
		GlobalSettings.set(global_var, default_val)
		GlobalSettings.save_settings()
		_update_toggle_btn(btn, default_val)
	)
	_attach_hover(row, desc)

func _update_toggle_btn(btn: Button, state: bool) -> void:
	btn.text = "Włączone" if state else "Wyłączone"
	if state: btn.add_theme_color_override("font_color", Color.GREEN)
	else: btn.add_theme_color_override("font_color", Color.GRAY)

func _attach_hover(row: Control, desc: String) -> void:
	var menu = _get_main_menu()
	if menu:
		row.mouse_entered.connect(func(): menu.set_hover_description(desc))
		row.mouse_exited.connect(func(): menu.set_hover_description(""))
		for child in row.get_children():
			if child is Control: child.mouse_entered.connect(func(): menu.set_hover_description(desc))

func _get_main_menu() -> Control:
	var curr = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu": return curr
		curr = curr.get_parent()
	return null
