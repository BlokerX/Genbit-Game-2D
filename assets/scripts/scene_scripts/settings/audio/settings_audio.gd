extends SettingsCategoryPanel
## Zakładka ustawień dźwięku (Głośność poszczególnych szyn AudioServer oraz dźwięk w tle).

func _ready() -> void:
	$Header/ResetBtn.pressed.connect(_on_category_reset_pressed)

	_setup_slider($MasterRow, "vol_master", GlobalSettings.default_vol_master, "Główna głośność całej gry.")
	_setup_slider($MusicRow, "vol_music", GlobalSettings.default_vol_music, "Głośność utworów muzycznych.")
	_setup_slider($SFXRow, "vol_sfx", GlobalSettings.default_vol_sfx, "Głośność ogólnych efektów dźwiękowych i interfejsu.")
	_setup_slider($EntitiesRow, "vol_entities", GlobalSettings.default_vol_entities, "Głośność dźwięków postaci, przedmiotów i innych encji.")
	_setup_slider($AmbientRow, "vol_ambient", GlobalSettings.default_vol_ambient, "Głośność środowiska: wiatru, deszczu, jaskiń i dźwięków otoczenia.")
	_setup_slider($UIRow, "vol_ui", GlobalSettings.default_vol_ui, "Głośność interfejsu, przycisków i elementów menu.")

	_setup_toggle_btn($SurroundRow, "surround_sound", GlobalSettings.default_surround_sound, "Włącza zaawansowany dźwięk przestrzenny (3D). Używaj na słuchawkach.")
	_setup_toggle_btn($MuteBgRow, "mute_in_background", GlobalSettings.default_mute_in_background, "Automatycznie wycisza grę po zminimalizowaniu okna (Alt-Tab).")

func update_ui() -> void:
	$MasterRow/Slider.value = GlobalSettings.vol_master
	$MusicRow/Slider.value = GlobalSettings.vol_music
	$SFXRow/Slider.value = GlobalSettings.vol_sfx
	$EntitiesRow/Slider.value = GlobalSettings.vol_entities
	$AmbientRow/Slider.value = GlobalSettings.vol_ambient
	$UIRow/Slider.value = GlobalSettings.vol_ui

	_update_toggle_btn($SurroundRow/ToggleBtn, GlobalSettings.surround_sound)
	_update_toggle_btn($MuteBgRow/ToggleBtn, GlobalSettings.mute_in_background)

func _on_category_reset_pressed() -> void:
	var menu: Control = _get_main_menu()
	if menu and menu.has_method("request_confirmation"):
		menu.call(
			"request_confirmation",
			"Reset Dźwięku",
			"Czy zresetować wszystkie ustawienia dźwięku do wartości domyślnych?",
			func():
				GlobalSettings.reset_category_audio(true)
				update_ui()
				menu.call("set_hover_description", "[color=green]Zresetowano ustawienia dźwięku.[/color]")
		)
