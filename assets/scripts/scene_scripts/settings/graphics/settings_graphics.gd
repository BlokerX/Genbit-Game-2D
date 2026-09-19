extends VBoxContainer

@export var mode_option: OptionButton
@export var reset_button: Button

func _ready() -> void:
	if reset_button: reset_button.pressed.connect(_on_category_reset_pressed)
	
	# KONFIGURACJA OPTION BUTTON (TRYB EKRANU)
	if mode_option:
		if mode_option.item_count == 0:
			mode_option.add_item("W Oknie", DisplayServer.WINDOW_MODE_WINDOWED)
			mode_option.add_item("Pełny Ekran", DisplayServer.WINDOW_MODE_FULLSCREEN)
			mode_option.add_item("Bez Ramki", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			
		mode_option.item_selected.connect(func(idx):
			GlobalSettings.display_mode = mode_option.get_item_id(idx)
			GlobalSettings.save_settings()
		)
		
		# Reset i Hover dla Opcji
		var m_row = mode_option.get_parent()
		var m_reset = m_row.get_node("ResetBtn")
		m_reset.pressed.connect(func():
			var def_idx = mode_option.get_item_index(GlobalSettings.default_display_mode)
			mode_option.select(def_idx)
			mode_option.item_selected.emit(def_idx)
		)
		_attach_hover(m_row, "W Oknie: Łatwe przełączanie. Pełny Ekran: Lepsza wydajność. Bez Ramki: Dobry balans.")
		
	# KONFIGURACJA RESZTY ZAKŁADEK
	_setup_toggle_btn($VsyncRow, "vsync_enabled", GlobalSettings.default_vsync_enabled, "Synchronizuje klatki gry z monitorem. Eliminuje 'rwanie' obrazu (Tearing).")
	
	_setup_slider($BrightnessRow, "brightness", GlobalSettings.default_brightness, "Reguluje jasność obrazu. Opcja użyteczna w ciemnych lochach.", false)
	_setup_slider($ContrastRow, "contrast", GlobalSettings.default_contrast, "Dostosowuje kontrast dla lepszej widoczności tekstur.", false)
	_setup_slider($SaturationRow, "saturation", GlobalSettings.default_saturation, "Intensywność kolorów. Możesz zredukować, by gra była mroczniejsza.", false)
	
	update_ui()

func update_ui() -> void:
	if mode_option: 
		# NAPRAWA BŁĘDU Z OPTIONBUTTON (Przekładamy ID na Indeks Listy)
		var item_idx = mode_option.get_item_index(GlobalSettings.display_mode)
		if item_idx != -1:
			mode_option.select(item_idx)
			
	$BrightnessRow/Slider.value = GlobalSettings.brightness
	$ContrastRow/Slider.value = GlobalSettings.contrast
	$SaturationRow/Slider.value = GlobalSettings.saturation
	_update_toggle_btn($VsyncRow/ToggleBtn, GlobalSettings.vsync_enabled)

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Grafiki", "Czy zresetować wszystkie ustawienia graficzne?", func():
			GlobalSettings.reset_category_graphics(true)
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano grafikę.[/color]")
		)

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

func _setup_slider(row: Control, global_var: String, default_val: float, desc: String, is_percent: bool = true) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(85, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.min_value = slider.min_value * 100 if is_percent else slider.min_value
	spin.max_value = slider.max_value * 100 if is_percent else slider.max_value
	spin.step = 1.0 if is_percent else slider.step
	if is_percent: spin.suffix = " %"
	
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
