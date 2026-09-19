extends VBoxContainer

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)
	
	_setup_slider($MasterRow, "vol_master", GlobalSettings.default_vol_master, "Główna głośność całej gry.")
	_setup_slider($MusicRow, "vol_music", GlobalSettings.default_vol_music, "Głośność utworów muzycznych.")
	_setup_slider($SFXRow, "vol_sfx", GlobalSettings.default_vol_sfx, "Głośność efektów dźwiękowych, interfejsu i strzałów.")
	_setup_slider($AmbientRow, "vol_ambient", GlobalSettings.default_vol_ambient, "Głośność szumu tła (wiatr, deszcz, jaskinie).")
	
	_setup_checkbox($SurroundRow, "surround_sound", GlobalSettings.default_surround_sound, "Włącza zaawansowany dźwięk przestrzenny (3D). Używaj na słuchawkach.")
	_setup_checkbox($MuteBgRow, "mute_in_background", GlobalSettings.default_mute_in_background, "Automatycznie wycisza grę po zminimalizowaniu okna (Alt-Tab).")

func update_ui() -> void:
	$MasterRow/Slider.value = GlobalSettings.vol_master
	$MusicRow/Slider.value = GlobalSettings.vol_music
	$SFXRow/Slider.value = GlobalSettings.vol_sfx
	$AmbientRow/Slider.value = GlobalSettings.vol_ambient
	$SurroundRow/CheckBox.button_pressed = GlobalSettings.surround_sound
	$MuteBgRow/CheckBox.button_pressed = GlobalSettings.mute_in_background

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Dźwięku", "Czy zresetować wszystkie ustawienia dźwięku do wartości domyślnych?", func():
			GlobalSettings.reset_category_audio(true)
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano ustawienia dźwięku.[/color]")
		)

# --- SYSTEM AUTOMATYCZNEGO GENEROWANIA LOGIKI I WSTAWIANIA SPINBOXA ---
func _setup_slider(row: Control, global_var: String, default_val: float, desc: String, is_percent: bool = true) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	
	# ZAMIANA LABELA NA SPINBOX (WPISYWANIE RĘCZNE Z KLAWIATURY)
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(85, 0)
	spin.min_value = slider.min_value * 100 if is_percent else slider.min_value
	spin.max_value = slider.max_value * 100 if is_percent else slider.max_value
	spin.step = slider.step * 100 if is_percent else slider.step
	if is_percent: spin.suffix = "%"
	
	# Usunięcie starej etykiety z podglądu i zastąpienie polem tekstowym
	val_lbl.get_parent().add_child(spin)
	val_lbl.get_parent().move_child(spin, val_lbl.get_index())
	val_lbl.queue_free()
	
	# Ustawienie wartości
	slider.value = GlobalSettings.get(global_var)
	spin.value = slider.value * 100 if is_percent else slider.value
	
	# Dwustronna komunikacja (Suwak <-> Pole tekstowe)
	slider.value_changed.connect(func(val):
		spin.value = val * 100 if is_percent else val
		GlobalSettings.set(global_var, val)
		GlobalSettings.save_settings()
	)
	spin.value_changed.connect(func(val):
		slider.value = val / 100.0 if is_percent else val
	)
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
		# Nakładamy Hover na całą linijkę ORAZ na poszczególne guziki
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
