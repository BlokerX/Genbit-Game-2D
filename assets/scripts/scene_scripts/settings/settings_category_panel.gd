extends VBoxContainer
class_name SettingsCategoryPanel
## Wspólna klasa bazowa dla wszystkich zakładek ustawień (Audio, Grafika, GUI, Sterowanie).
## Realizuje zasady DRY oraz Single Responsibility (SOLID), eliminując potrójną duplikację
## logiki suwaków, przełączników (Toggle) oraz opisów po najechaniu kursorem (Hover).

const PERCENT_MULTIPLIER: float = 100.0
const DEFAULT_PERCENT_SLIDER_STEP: float = 0.01
const DEFAULT_SPINBOX_STEP: float = 1.0
const DEFAULT_SPINBOX_MIN_SIZE := Vector2(90.0, 36.0)

const ENABLED_TEXT: String = "Włączone"
const DISABLED_TEXT: String = "Wyłączone"
const ENABLED_COLOR: Color = Color.GREEN
const DISABLED_COLOR: Color = Color.GRAY

## Konfiguruje wiersz z suwakiem (Slider), dynamicznie tworząc pole liczbowe (SpinBox) w miejsce starego ValLabel.
func _setup_slider(
	row: Control,
	global_var: String,
	default_val: float,
	desc: String,
	is_percent: bool = true
) -> void:
	if row == null:
		return
	var slider: Slider = row.get_node_or_null("Slider") as Slider
	var val_lbl: Label = row.get_node_or_null("ValLabel") as Label
	var reset_btn: Button = row.get_node_or_null("ResetBtn") as Button
	if slider == null:
		return

	if is_percent:
		slider.step = DEFAULT_PERCENT_SLIDER_STEP

	var spin: SpinBox = SpinBox.new()
	spin.custom_minimum_size = DEFAULT_SPINBOX_MIN_SIZE
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.min_value = slider.min_value * PERCENT_MULTIPLIER if is_percent else slider.min_value
	spin.max_value = slider.max_value * PERCENT_MULTIPLIER if is_percent else slider.max_value
	spin.step = DEFAULT_SPINBOX_STEP if is_percent else slider.step
	spin.suffix = " %" if is_percent else ""
	if spin.get_line_edit() != null:
		spin.get_line_edit().expand_to_text_length = true

	if val_lbl != null and val_lbl.get_parent() != null:
		var lbl_parent: Node = val_lbl.get_parent()
		lbl_parent.add_child(spin)
		lbl_parent.move_child(spin, val_lbl.get_index())
		val_lbl.queue_free()

	var current_val: float = float(GlobalSettings.get(global_var))
	slider.value = current_val
	spin.value = current_val * PERCENT_MULTIPLIER if is_percent else current_val

	slider.value_changed.connect(func(val: float):
		var target_spin_val: float = val * PERCENT_MULTIPLIER if is_percent else val
		if not is_equal_approx(spin.value, target_spin_val):
			spin.set_value_no_signal(target_spin_val)
		GlobalSettings.set(global_var, val)
		GlobalSettings.save_settings()
	)

	spin.value_changed.connect(func(val: float):
		var target_slider_val: float = val / PERCENT_MULTIPLIER if is_percent else val
		if not is_equal_approx(slider.value, target_slider_val):
			slider.value = target_slider_val
	)

	if reset_btn != null:
		reset_btn.pressed.connect(func(): slider.value = default_val)

	_attach_hover(row, desc)

## Konfiguruje wiersz z przyciskiem przełączającym (Włączone / Wyłączone) oraz przyciskiem resetu.
func _setup_toggle_btn(
	row: Control,
	global_var: String,
	default_val: bool,
	desc: String,
	on_changed_callback: Callable = Callable()
) -> void:
	if row == null:
		return
	var btn: Button = row.get_node_or_null("ToggleBtn") as Button
	var reset_btn: Button = row.get_node_or_null("ResetBtn") as Button
	if btn == null:
		return

	_update_toggle_btn(btn, bool(GlobalSettings.get(global_var)))

	btn.pressed.connect(func():
		var new_val: bool = not bool(GlobalSettings.get(global_var))
		GlobalSettings.set(global_var, new_val)
		GlobalSettings.save_settings()
		_update_toggle_btn(btn, new_val)
		if on_changed_callback.is_valid():
			on_changed_callback.call()
	)

	if reset_btn != null:
		reset_btn.pressed.connect(func():
			GlobalSettings.set(global_var, default_val)
			GlobalSettings.save_settings()
			_update_toggle_btn(btn, default_val)
			if on_changed_callback.is_valid():
				on_changed_callback.call()
		)

	_attach_hover(row, desc)

## Aktualizuje tekst i kolor czcionki na przycisku przełącznika (Zielony = Włączone, Szary = Wyłączone).
func _update_toggle_btn(btn: Button, state: bool) -> void:
	if btn == null:
		return
	btn.text = ENABLED_TEXT if state else DISABLED_TEXT
	btn.add_theme_color_override("font_color", ENABLED_COLOR if state else DISABLED_COLOR)

## Podpina wyświetlanie opisu pomocniczego na dole okna SettingsMenu po najechaniu myszką na wiersz.
func _attach_hover(row: Control, desc: String) -> void:
	if row == null:
		return
	var menu: Control = _get_main_menu()
	if menu != null and menu.has_method("set_hover_description"):
		row.mouse_entered.connect(func(): menu.call("set_hover_description", desc))
		row.mouse_exited.connect(func(): menu.call("set_hover_description", ""))
		for child in row.get_children():
			if child is Control:
				(child as Control).mouse_entered.connect(func(): menu.call("set_hover_description", desc))

## Wyszukuje nadrzędny kontroler SettingsMenu w górę drzewa sceny (uniezależnia zakładki od sztywnej ścieżki).
func _get_main_menu() -> Control:
	var curr: Node = get_parent()
	while curr != null:
		if curr.name == "SettingsMenu" or curr.has_method("request_confirmation"):
			return curr as Control
		curr = curr.get_parent()
	return null
