extends CanvasLayer
## Globalny menedżer przejść ekranowych (Fade-In / Fade-Out) oraz opcjonalnego ekranu ładowania poziomów.

signal on_fade_out_finished
signal on_fade_in_finished

# --- STAŁE KONFIGURACYJNE (Brak magicznych liczb) ---
const DEFAULT_FADE_DURATION_SEC: float = 0.5
const LOADING_PANEL_WIDTH: float = 480.0
const LOADING_PANEL_HEIGHT: float = 130.0
const LOADING_BAR_HEIGHT: float = 26.0
const TITLE_FONT_SIZE: int = 24
const STATUS_FONT_SIZE: int = 16
const PERCENT_MULTIPLIER: float = 100.0
const PANEL_CORNER_RADIUS: int = 10
const BAR_CORNER_RADIUS: int = 6
const BORDER_WIDTH_PX: int = 2

@onready var color_rect: ColorRect = ColorRect.new()

var _loading_container: CenterContainer
var _title_label: Label
var _status_label: Label
var _progress_bar: ProgressBar

var _active_tween: Tween
var _active_target_alpha: float = 0.0
var _active_completion: Callable
var _is_transitioning: bool = false
## Określa, czy dla bieżącego przejścia między poziomami włączono wyświetlanie paska ładowania.
var _is_loading_screen_enabled: bool = false

func _ready() -> void:
	layer = GameLayers.UI_TRANSITION # Najwyższa warstwa, by zakryć grę i całe UI
	process_mode = Node.PROCESS_MODE_ALWAYS

	color_rect.color = Color(0.0, 0.0, 0.0, 0.0) # Na start całkowicie przezroczysty
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

	_build_loading_overlay()

## Tworzy czytelny, kontrastowy interfejs paska ładowania (ukryty podczas zwykłej gry i przejść między pokojami).
func _build_loading_overlay() -> void:
	_loading_container = CenterContainer.new()
	_loading_container.name = "LoadingContainer"
	_loading_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_container.hide()
	add_child(_loading_container)

	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.11, 0.96)
	panel_style.border_color = Color(0.75, 0.62, 0.28, 1.0)
	panel_style.set_border_width_all(BORDER_WIDTH_PX)
	panel_style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_loading_container.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(LOADING_PANEL_WIDTH, LOADING_PANEL_HEIGHT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "ŁADOWANIE ŚWIATA..."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.35, 1.0))
	vbox.add_child(_title_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(LOADING_PANEL_WIDTH, LOADING_BAR_HEIGHT)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = PERCENT_MULTIPLIER
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = true

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.16, 0.16, 0.20, 1.0)
	bg_style.border_color = Color(0.45, 0.42, 0.35, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(BAR_CORNER_RADIUS)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.88, 0.68, 0.20, 1.0)
	fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)

	_progress_bar.add_theme_stylebox_override("background", bg_style)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	vbox.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = "Przygotowywanie poziomu..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 1.0))
	vbox.add_child(_status_label)

func _exit_tree() -> void:
	_cancel_active_fade()

## Jawnie aktywuje ekran ładowania z paskiem postępu (wywoływane wyłącznie przez GlobalLevelManager).
func show_loading_screen(status_text: String = "Ładowanie poziomu...", progress_ratio: float = 0.0) -> void:
	_is_loading_screen_enabled = true
	if is_instance_valid(color_rect):
		color_rect.color.a = 1.0
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_loading_container):
		_status_label.text = status_text
		_progress_bar.value = clampf(progress_ratio * PERCENT_MULTIPLIER, 0.0, PERCENT_MULTIPLIER)
		_loading_container.show()

## Aktualizuje pasek postępu TYLKO wtedy, gdy ekran ładowania jest aktywny (_is_loading_screen_enabled == true).
func update_loading_progress(progress_ratio: float, status_text: String = "") -> void:
	if not _is_loading_screen_enabled or not is_instance_valid(_loading_container):
		return
	_progress_bar.value = clampf(progress_ratio * PERCENT_MULTIPLIER, 0.0, PERCENT_MULTIPLIER)
	if status_text != "":
		_status_label.text = status_text

## Ukrywa pasek ładowania i odblokowuje myszkę.
func hide_loading_screen() -> void:
	_is_loading_screen_enabled = false
	if is_instance_valid(color_rect):
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_loading_container):
		_loading_container.hide()

## Zwraca true, jeśli ekran jest już całkowicie zaciemniony.
func is_screen_black() -> bool:
	return is_instance_valid(color_rect) and color_rect.color.a >= 0.98

func fade_to_black(duration: float = DEFAULT_FADE_DURATION_SEC) -> void:
	_start_fade(1.0, duration, _emit_fade_out_finished)

func fade_to_normal(duration: float = DEFAULT_FADE_DURATION_SEC) -> void:
	hide_loading_screen()
	_start_fade(0.0, duration, _emit_fade_in_finished)

func is_transition_active() -> bool:
	return _is_transitioning

func _start_fade(target_alpha: float, duration: float, completion: Callable) -> void:
	_cancel_active_fade()
	_active_target_alpha = target_alpha
	_active_completion = completion
	_is_transitioning = true

	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.tween_property(color_rect, "color:a", target_alpha, duration).set_trans(
		Tween.TRANS_SINE
	)
	_active_tween.finished.connect(_complete_active_fade)

func _cancel_active_fade() -> void:
	if _active_tween == null:
		return
	if not _active_tween.is_valid():
		_complete_active_fade()
		return
	_active_tween.kill()
	color_rect.color.a = _active_target_alpha
	_complete_active_fade()

func _complete_active_fade() -> void:
	var completion: Callable = _active_completion
	_active_tween = null
	_active_completion = Callable()
	_is_transitioning = false
	if completion.is_valid():
		completion.call()

func _emit_fade_out_finished() -> void:
	on_fade_out_finished.emit()

func _emit_fade_in_finished() -> void:
	on_fade_in_finished.emit()
