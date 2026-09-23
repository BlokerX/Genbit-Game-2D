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
	
	# KONFIGURACJA SPECJALNA: Zasięg Renderowania (Chunking)
	var render_distance_row = get_node_or_null("RenderDistanceRow")
	if render_distance_row:
		_setup_render_distance_slider(render_distance_row, "chunk_render_distance", GlobalSettings.default_chunk_render_distance)
	
	update_ui()

func update_ui() -> void:
	if mode_option: 
		var item_idx = mode_option.get_item_index(GlobalSettings.display_mode)
		if item_idx != -1:
			mode_option.select(item_idx)
			
	$BrightnessRow/Slider.value = GlobalSettings.brightness
	$ContrastRow/Slider.value = GlobalSettings.contrast
	$SaturationRow/Slider.value = GlobalSettings.saturation
	_update_toggle_btn($VsyncRow/ToggleBtn, GlobalSettings.vsync_enabled)
	
	var render_slider = get_node_or_null("RenderDistanceRow/Slider")
	if render_slider:
		render_slider.value = GlobalSettings.chunk_render_distance

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

# --- DEDYKOWANA FUNKCJA DLA SUWAKA CHUNKÓW Z DYNAMICZNYMI OPISAMI ---
func _setup_render_distance_slider(row: Control, global_var: String, default_val: float) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	
	# Baza dokładnych opisów dla każdego z 12 poziomów
	var dynamic_descriptions = [
		"Poziom 1: 1 chunk (Aktywny tylko kwadrat z graczem)",
		"Poziom 2: 5 chunków (Kształt krzyża - B. Wysoka Wydajność)",
		"Poziom 3: 9 chunków (Kwadrat 3x3 - Złoty Środek)",
		"Poziom 4: 13 chunków (Kształt diamentu)",
		"Poziom 5: 21 chunków (Zaokrąglony okrąg 5x5)",
		"Poziom 6: 25 chunków (Pełen kwadrat 5x5)",
		"Poziom 7: 37 chunków (Większy okrąg)",
		"Poziom 8: 49 chunków (Kwadrat 7x7)",
		"Poziom 9: 69 chunków (Duży okrąg)",
		"Poziom 10: 81 chunków (Kwadrat 9x9)",
		"Poziom 11: 145 chunków (Ogromny okrąg 13x13)",
		"Poziom 12: 225 chunków (Kwadrat 15x15 - Ekstremalne zużycie zasobów!)"
	]
	
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(85, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.min_value = slider.min_value
	spin.max_value = slider.max_value
	spin.step = slider.step
	
	val_lbl.get_parent().add_child(spin)
	val_lbl.get_parent().move_child(spin, val_lbl.get_index())
	val_lbl.queue_free()
	
	slider.value = GlobalSettings.get(global_var)
	spin.value = slider.value
	
	# Funkcja wyciągająca aktualny opis
	var menu = _get_main_menu()
	var update_dynamic_hover = func():
		if menu:
			var idx = clampi(int(slider.value) - 1, 0, dynamic_descriptions.size() - 1)
			menu.set_hover_description("[color=cyan]" + dynamic_descriptions[idx] + "[/color]")
	
	# Podpięcie zdarzeń hover
	row.mouse_entered.connect(update_dynamic_hover)
	row.mouse_exited.connect(func(): if menu: menu.set_hover_description(""))
	for child in row.get_children():
		if child is Control:
			child.mouse_entered.connect(update_dynamic_hover)
	
	# Zdarzenia zmiany wartości
	slider.value_changed.connect(func(val):
		spin.value = val
		GlobalSettings.set(global_var, val)
		GlobalSettings.save_settings()
		# Jeśli myszka nadal znajduje się nad rzędem, zaktualizuj tekst od razu po przesunięciu
		if row.get_global_rect().has_point(row.get_global_mouse_position()):
			update_dynamic_hover.call()
	)
	spin.value_changed.connect(func(val): slider.value = val)
	reset_btn.pressed.connect(func(): slider.value = default_val)

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
