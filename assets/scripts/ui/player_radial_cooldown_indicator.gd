class_name PlayerRadialCooldownIndicator
extends Node2D
## Kołowy wskaźnik czasu odnowienia akcji (Cooldown / Przeładowanie / Ogłuszenie) wyświetlany bezpośrednio przy graczu (w stylu Fortnite).
## Automatycznie usypia pętlę _process(), gdy akcja jest gotowa, zapewniając zerowe obciążenie procesora w spoczynku (SOLID - SRP).

#region Stałe Geometryczne i Wizualne (Brak magicznych liczb)
const START_ANGLE_RAD: float = -PI / 2.0
const FULL_CIRCLE_RAD: float = TAU
const ARC_POINT_COUNT: int = 40
const READY_FLASH_DURATION_SEC: float = 0.18
const READY_FLASH_SCALE_MULTIPLIER: float = 1.18
const MIN_DISPLAY_DURATION_THRESHOLD_SEC: float = 0.08
const MIN_VISIBLE_PROGRESS_RATIO: float = 0.005
const INNER_DISC_ALPHA_MULTIPLIER: float = 0.65
const OUTER_RIM_EXTRA_THICKNESS_PX: float = 2.5
const DECIMAL_TIME_THRESHOLD_SEC: float = 10.0
const LABEL_VERTICAL_OFFSET_PX: float = 5.0
const LABEL_FONT_SIZE: int = 11
const LABEL_OUTLINE_SIZE: int = 3
const Z_INDEX_OFFSET_ABOVE_HIGHLIGHT: int = 5
#endregion

@export_group("Pozycja i Rozmiar Koła")
## Przesunięcie koła ładowania względem środka postaci gracza (domyślnie z prawej strony na wysokości ramienia/dłoni).
@export var indicator_offset: Vector2 = Vector2(54.0, -18.0)
## Promień koła ładowania w pikselach.
@export_range(10.0, 64.0, 1.0) var ring_radius: float = 18.0
## Grubość linii pierścienia w pikselach.
@export_range(2.0, 14.0, 0.5) var ring_thickness: float = 4.5
## Czy wewnątrz koła wyświetlać pozostały czas w sekundach (np. "0.8")?
@export var show_numeric_timer: bool = true

@export_group("Kolorystyka (Styl Fortnite)")
## Kolor ciemnego podkładu pierścienia.
@export var track_bg_color: Color = Color(0.05, 0.06, 0.09, 0.78)
## Kolor zewnętrznej obwódki zapewniającej kontrast na jasnym tle (np. lawa, kwas).
@export var outer_rim_color: Color = Color(0.0, 0.0, 0.0, 0.85)
## Kolor postępu podczas ładowania (jasny błękit / biel).
@export var progress_fill_color: Color = Color(0.35, 0.88, 1.0, 0.96)
## Kolor rozbłysku w ułamku sekundy, gdy ładowanie dobiegnie końca.
@export var ready_flash_color: Color = Color(0.55, 1.0, 0.65, 1.0)

var _player: CharacterEntity = null
var _stats: InteractionAndAttackStatsComponent = null
var _current_ratio: float = 1.0
var _remaining_sec: float = 0.0
var _ready_flash_timer: float = 0.0

func _ready() -> void:
	z_index = GameLayers.INTERACTABLE_HIGHLIGHT + Z_INDEX_OFFSET_ABOVE_HIGHLIGHT
	hide()
	set_process(false)

## Inicjalizuje wskaźnik i podpina go pod sygnały komponentu statystyk ataku gracza.
func initialize(player: CharacterEntity, stats: InteractionAndAttackStatsComponent) -> void:
	_player = player
	_stats = stats
	if _stats == null:
		return

	if not _stats.cooldown_started.is_connected(_on_cooldown_started):
		_stats.cooldown_started.connect(_on_cooldown_started)
	if not _stats.cooldown_ready.is_connected(_on_cooldown_ready):
		_stats.cooldown_ready.connect(_on_cooldown_ready)

	if _stats.can_attack():
		hide()
		set_process(false)
	else:
		_on_cooldown_started()

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _stats == null:
		hide()
		set_process(false)
		return

	# Utrzymujemy stałą orientację wskaźnika niezależnie od obrotu węzła rodzica
	global_rotation = 0.0
	global_position = _player.global_position + indicator_offset

	if _player.is_dead or _player.is_respawning:
		hide()
		set_process(false)
		return

	if _ready_flash_timer > 0.0:
		_ready_flash_timer = maxf(0.0, _ready_flash_timer - delta)
		queue_redraw()
		if _ready_flash_timer <= 0.0 and _stats.can_attack():
			hide()
			set_process(false)
		return

	_remaining_sec = _stats.get_remaining_cooldown()
	if _remaining_sec <= 0.0:
		_trigger_ready_flash()
		return

	_current_ratio = _stats.get_cooldown_progress_ratio()
	queue_redraw()

## Budzi wskaźnik i rozpoczyna rysowanie pierścienia w momencie startu cooldownu, przeładowania lub ogłuszenia.
func _on_cooldown_started() -> void:
	if _stats == null:
		return
	var total_rem: float = _stats.get_remaining_cooldown()
	if total_rem < MIN_DISPLAY_DURATION_THRESHOLD_SEC:
		return
	_ready_flash_timer = 0.0
	_remaining_sec = total_rem
	_current_ratio = _stats.get_cooldown_progress_ratio()
	if is_instance_valid(_player):
		global_rotation = 0.0
		global_position = _player.global_position + indicator_offset
	show()
	set_process(true)
	queue_redraw()

## Wyzwala krótki rozbłysk gotowości i usypia wskaźnik po zakończeniu odnawiania.
func _on_cooldown_ready() -> void:
	if visible and _ready_flash_timer <= 0.0:
		_trigger_ready_flash()
	else:
		hide()
		set_process(false)

func _trigger_ready_flash() -> void:
	_current_ratio = 1.0
	_remaining_sec = 0.0
	_ready_flash_timer = READY_FLASH_DURATION_SEC
	queue_redraw()

func _draw() -> void:
	var fade_alpha: float = 1.0
	var active_color: Color = progress_fill_color
	var current_radius: float = ring_radius

	if _ready_flash_timer > 0.0:
		var flash_ratio: float = _ready_flash_timer / READY_FLASH_DURATION_SEC
		fade_alpha = flash_ratio
		active_color = ready_flash_color
		current_radius = lerpf(ring_radius * READY_FLASH_SCALE_MULTIPLIER, ring_radius, flash_ratio)

	var bg_col: Color = track_bg_color
	bg_col.a *= fade_alpha
	var rim_col: Color = outer_rim_color
	rim_col.a *= fade_alpha
	active_color.a *= fade_alpha

	# 1. Tarcza wewnętrzna (półprzezroczysty środek poprawiający czytelność cyfr)
	draw_circle(Vector2.ZERO, current_radius, Color(bg_col.r, bg_col.g, bg_col.b, bg_col.a * INNER_DISC_ALPHA_MULTIPLIER))

	# 2. Ciemny obrys zewnętrzny i tor pierścienia
	draw_arc(
		Vector2.ZERO,
		current_radius,
		0.0,
		FULL_CIRCLE_RAD,
		ARC_POINT_COUNT,
		rim_col,
		ring_thickness + OUTER_RIM_EXTRA_THICKNESS_PX,
		true
	)
	draw_arc(Vector2.ZERO, current_radius, 0.0, FULL_CIRCLE_RAD, ARC_POINT_COUNT, bg_col, ring_thickness, true)

	# 3. Wypełnienie łuku postępu (od góry zgodnie z ruchem wskazówek zegara)
	var clamped_ratio: float = clampf(_current_ratio, 0.0, 1.0)
	if clamped_ratio > MIN_VISIBLE_PROGRESS_RATIO:
		var end_angle: float = START_ANGLE_RAD + (FULL_CIRCLE_RAD * clamped_ratio)
		draw_arc(Vector2.ZERO, current_radius, START_ANGLE_RAD, end_angle, ARC_POINT_COUNT, active_color, ring_thickness, true)

	# 4. Kompaktowy licznik czasu w środku koła
	if show_numeric_timer and _remaining_sec > 0.0:
		var font: Font = ThemeDB.fallback_font
		if font != null:
			var time_text: String = (
				"%.1f" % _remaining_sec
				if _remaining_sec < DECIMAL_TIME_THRESHOLD_SEC
				else str(int(ceil(_remaining_sec)))
			)
			var text_size: Vector2 = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
			var draw_pos := Vector2(-text_size.x * 0.5, LABEL_VERTICAL_OFFSET_PX)
			draw_string_outline(
				font,
				draw_pos,
				time_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				LABEL_FONT_SIZE,
				LABEL_OUTLINE_SIZE,
				Color(0.0, 0.0, 0.0, fade_alpha)
			)
			draw_string(
				font,
				draw_pos,
				time_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				LABEL_FONT_SIZE,
				Color(1.0, 1.0, 1.0, fade_alpha)
			)
