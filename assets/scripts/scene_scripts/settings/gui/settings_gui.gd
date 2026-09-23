extends VBoxContainer

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)
	
	_setup_slider($ScaleGlobalRow, "ui_scale_global", GlobalSettings.default_ui_scale_global, "Zmienia globalną skalę całego obrazu 2D i silnika.")
	_setup_slider($ScaleGameRow, "ui_scale_game", GlobalSettings.default_ui_scale_game, "Powiększa ikony i paski tylko podczas właściwej rozgrywki.")
	_setup_slider($ScaleMenuRow, "ui_scale_menu", GlobalSettings.default_ui_scale_menu, "Powiększa elementy takie jak okna craftingu czy ekwipunku.")
	
	# MASTER PRZYCISK
	_setup_master_toggle()
	
	_setup_toggle_btn($MainStatsRow, "show_main_stats", GlobalSettings.default_show_main_stats, "Wyświetla Avatar postaci, aktualne punkty zdrowia oraz pasek umiejętności.")
	_setup_toggle_btn($ExtraStatsRow, "show_extra_stats", GlobalSettings.default_show_extra_stats, "Wyświetla zaawansowane statystyki (DMG, Ochrona, Szybkość) po lewej stronie.")
	_setup_toggle_btn($ActiveEffectsRow, "show_active_effects", GlobalSettings.default_show_active_effects, "Pokazuje ikony statusów (np. trucizna, szybkość) wraz z licznikiem czasu.")
	_setup_toggle_btn($HotbarRow, "show_hotbar", GlobalSettings.default_show_hotbar, "Pokazuje dolny pasek szybkiego dostępu (Sloty 1-9).")
	_setup_toggle_btn($ItemInfoRow, "show_item_info", GlobalSettings.default_show_item_info, "Panel w prawym górnym rogu z opisem obecnie trzymanego przedmiotu.")
	_setup_toggle_btn($PlaytimeRow, "show_playtime", GlobalSettings.default_show_playtime, "Licznik czasu gry na środku górnej części ekranu.")
	_setup_toggle_btn($MinimapRow, "show_minimap", GlobalSettings.default_show_minimap, "Pokazuje Minimapę ułatwiającą eksplorację proceduralnego świata.")
	_setup_toggle_btn($QuestRow, "show_quest_log", GlobalSettings.default_show_quest_log, "Pokazuje panel śledzenia obecnie wybranego zadania fabularnego.")
	
	# Opcje Deweloperskie ustawione identycznie jak pozostałe:
	_setup_toggle_btn($ChunkGridRow, "show_chunk_grid", GlobalSettings.default_show_chunk_grid, "Wyświetla siatkę chunków nałożoną na świat. Przydatne do testowania wydajności i zasięgu.")
	_setup_toggle_btn($MinimapDevRow, "use_developer_camera", GlobalSettings.default_use_developer_camera, "Wymusza renderowanie minimapy na żywo (pożera FPS). Wyłącz by używać map PNG.")

func update_ui() -> void:
	$ScaleGlobalRow/Slider.value = GlobalSettings.ui_scale_global
	$ScaleGameRow/Slider.value = GlobalSettings.ui_scale_game
	$ScaleMenuRow/Slider.value = GlobalSettings.ui_scale_menu
	
	_update_toggle_btn($MainStatsRow/ToggleBtn, GlobalSettings.show_main_stats)
	_update_toggle_btn($ExtraStatsRow/ToggleBtn, GlobalSettings.show_extra_stats)
	_update_toggle_btn($ActiveEffectsRow/ToggleBtn, GlobalSettings.show_active_effects)
	_update_toggle_btn($HotbarRow/ToggleBtn, GlobalSettings.show_hotbar)
	_update_toggle_btn($ItemInfoRow/ToggleBtn, GlobalSettings.show_item_info)
	_update_toggle_btn($PlaytimeRow/ToggleBtn, GlobalSettings.show_playtime)
	_update_toggle_btn($MinimapRow/ToggleBtn, GlobalSettings.show_minimap)
	_update_toggle_btn($QuestRow/ToggleBtn, GlobalSettings.show_quest_log)
	
	_update_toggle_btn($ChunkGridRow/ToggleBtn, GlobalSettings.show_chunk_grid)
	_update_toggle_btn($MinimapDevRow/ToggleBtn, GlobalSettings.use_developer_camera)
	
	_update_master_btn_visual()

func _on_category_reset_pressed() -> void:
	var menu = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.request_confirmation("Reset Interfejsu", "Czy zresetować wszystkie ustawienia GUI?", func():
			GlobalSettings.reset_category_gui(true)
			
			# Twardy reset dla opcji deweloperskich
			GlobalSettings.show_chunk_grid = GlobalSettings.default_show_chunk_grid
			GlobalSettings.use_developer_camera = GlobalSettings.default_use_developer_camera
			GlobalSettings.save_settings()
			
			update_ui()
			menu.set_hover_description("[color=green]Zresetowano interfejs.[/color]")
		)

# --- SYSTEM GŁÓWNEGO PRZEŁĄCZNIKA (MASTER TOGGLE) ---
func _setup_master_toggle() -> void:
	var btn: Button = $HUDMasterRow/ToggleBtn
	var reset_btn: Button = $HUDMasterRow/ResetBtn
	
	_update_master_btn_visual()
	
	btn.pressed.connect(func():
		var all_true = _are_all_huds_enabled()
		var new_state = not all_true 
		
		GlobalSettings.show_main_stats = new_state
		GlobalSettings.show_extra_stats = new_state
		GlobalSettings.show_active_effects = new_state
		GlobalSettings.show_hotbar = new_state
		GlobalSettings.show_item_info = new_state
		GlobalSettings.show_playtime = new_state
		GlobalSettings.show_minimap = new_state
		GlobalSettings.show_quest_log = new_state
		GlobalSettings.save_settings()
		update_ui()
	)
	
	reset_btn.pressed.connect(func():
		GlobalSettings.show_main_stats = GlobalSettings.default_show_main_stats
		GlobalSettings.show_extra_stats = GlobalSettings.default_show_extra_stats
		GlobalSettings.show_active_effects = GlobalSettings.default_show_active_effects
		GlobalSettings.show_hotbar = GlobalSettings.default_show_hotbar
		GlobalSettings.show_item_info = GlobalSettings.default_show_item_info
		GlobalSettings.show_playtime = GlobalSettings.default_show_playtime
		GlobalSettings.show_minimap = GlobalSettings.default_show_minimap
		GlobalSettings.show_quest_log = GlobalSettings.default_show_quest_log
		GlobalSettings.save_settings()
		update_ui()
	)
	_attach_hover($HUDMasterRow, "Inteligentny przycisk. Zarządza wszystkimi kafelkami interfejsu w grze naraz.")

func _are_all_huds_enabled() -> bool:
	return (GlobalSettings.show_main_stats and GlobalSettings.show_extra_stats and 
			GlobalSettings.show_active_effects and GlobalSettings.show_hotbar and 
			GlobalSettings.show_item_info and GlobalSettings.show_playtime and 
			GlobalSettings.show_minimap and GlobalSettings.show_quest_log)

func _update_master_btn_visual() -> void:
	var btn: Button = $HUDMasterRow/ToggleBtn
	var all_true = _are_all_huds_enabled()
	var all_false = not (GlobalSettings.show_main_stats or GlobalSettings.show_extra_stats or 
						GlobalSettings.show_active_effects or GlobalSettings.show_hotbar or 
						GlobalSettings.show_item_info or GlobalSettings.show_playtime or 
						GlobalSettings.show_minimap or GlobalSettings.show_quest_log)
						
	if all_true:
		btn.text = "Wszystko Włączone"
		btn.add_theme_color_override("font_color", Color.GREEN)
	elif all_false:
		btn.text = "Wszystko Wyłączone"
		btn.add_theme_color_override("font_color", Color.GRAY)
	else:
		btn.text = "Niestandardowe (Część)"
		btn.add_theme_color_override("font_color", Color.ORANGE)

# --- SYSTEMY SKALI I PRZYCISKÓW ---
func _setup_slider(row: Control, global_var: String, default_val: float, desc: String, is_percent: bool = true) -> void:
	var slider: Slider = row.get_node("Slider")
	var val_lbl: Label = row.get_node("ValLabel")
	var reset_btn: Button = row.get_node("ResetBtn")
	slider.step = 0.01 
	
	var spin = SpinBox.new()
	spin.custom_minimum_size = Vector2(100, 40)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.min_value = slider.min_value * 100 if is_percent else slider.min_value
	spin.max_value = slider.max_value * 100 if is_percent else slider.max_value
	spin.step = 1.0 
	spin.suffix = " %" if is_percent else ""
	spin.get_line_edit().expand_to_text_length = true 
	
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

func _setup_toggle_btn(row: Control, global_var: String, default_val: bool, desc: String) -> void:
	var btn: Button = row.get_node("ToggleBtn")
	var reset_btn: Button = row.get_node("ResetBtn")
	_update_toggle_btn(btn, GlobalSettings.get(global_var))
	
	btn.pressed.connect(func():
		var new_val = not GlobalSettings.get(global_var)
		GlobalSettings.set(global_var, new_val)
		GlobalSettings.save_settings()
		_update_toggle_btn(btn, new_val)
		_update_master_btn_visual()
	)
	reset_btn.pressed.connect(func():
		GlobalSettings.set(global_var, default_val)
		GlobalSettings.save_settings()
		_update_toggle_btn(btn, default_val)
		_update_master_btn_visual()
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
