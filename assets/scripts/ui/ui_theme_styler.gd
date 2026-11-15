class_name UIThemeStyler
extends RefCounted
## Centralny serwis stylizacji interfejsu użytkownika (SOLID - Single Responsibility oraz DRY).
## Definiuje spójną paletę kolorystyczną i generatory stylów dla kafelków HUD, pasków stanu, okien menu, przycisków oraz dymków Tooltipów.

#region Paleta Kolorów Motywu (Brak magicznych liczb)
## Kolor tła głównych okien menu (Ekwipunek, Skrzynia, Crafting) spójny z Dziennikiem Zadań.
const WINDOW_BG_COLOR := Color(0.08, 0.08, 0.11, 0.96)
## Złoty kolor obramowania głównych okien menu.
const WINDOW_BORDER_COLOR := Color(0.72, 0.60, 0.30, 1.0)
## Kolor cienia pod głównymi oknami menu.
const WINDOW_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.55)

## Półprzezroczysty kolor tła nieinwazyjnych kafelków HUD (Statystyki, Zegar, Efekty, Informacje o Przedmiocie).
const HUD_CARD_BG_COLOR := Color(0.06, 0.07, 0.10, 0.74)
## Subtelny kolor obramowania kafelków HUD.
const HUD_CARD_BORDER_COLOR := Color(0.55, 0.48, 0.30, 0.48)
## Kolor delikatnego cienia pod kafelkami HUD.
const HUD_CARD_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)

## Kolor ciemnego toru pod paskami postępu (HP, Cooldown, Wytrzymałość).
const BAR_TRACK_BG_COLOR := Color(0.08, 0.09, 0.12, 0.88)
## Kolor obramowania pasków postępu.
const BAR_BORDER_COLOR := Color(0.18, 0.20, 0.25, 0.95)
## Kolor wewnętrznego obrysu wypełnienia paska postępu.
const BAR_FILL_HIGHLIGHT_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.22)
## Domyślny kolor wypełnienia paska zdrowia gracza.
const HP_BAR_FILL_COLOR := Color(0.28, 0.82, 0.36, 0.92)
## Domyślny kolor wypełnienia paska czasu odnowienia na HUD-zie.
const COOLDOWN_BAR_FILL_COLOR := Color(0.32, 0.78, 0.96, 0.90)

## Kolory stanów przycisków interfejsu (Normal, Hover, Pressed, Disabled).
const BUTTON_NORMAL_BG := Color(0.14, 0.15, 0.20, 0.90)
const BUTTON_HOVER_BG := Color(0.22, 0.23, 0.30, 0.96)
const BUTTON_PRESSED_BG := Color(0.28, 0.25, 0.18, 0.98)
const BUTTON_DISABLED_BG := Color(0.10, 0.10, 0.13, 0.60)
const BUTTON_BORDER_NORMAL := Color(0.42, 0.40, 0.34, 0.80)
const BUTTON_BORDER_ACCENT := Color(0.85, 0.72, 0.35, 1.0)
const BUTTON_BORDER_DISABLED := Color(0.25, 0.25, 0.28, 0.50)

## Kolory typografii zapewniające czytelność tekstu na dowolnym tle rozgrywki.
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const TEXT_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.95)
const HEADER_GOLD_COLOR := Color(0.96, 0.84, 0.42, 1.0)
const BODY_LIGHT_TEXT_COLOR := Color(0.92, 0.94, 0.98, 1.0)
const DEBUG_TEXT_COLOR := Color(0.85, 0.95, 1.0, 0.90)
#endregion

#region Stałe Wymiarów Geometrycznych (Brak magicznych liczb)
const WINDOW_CORNER_RADIUS: int = 12
const WINDOW_BORDER_WIDTH: int = 2
const WINDOW_SHADOW_SIZE: int = 14
const WINDOW_DEFAULT_PADDING_PX: float = 20.0

const HUD_CARD_CORNER_RADIUS: int = 7
const HUD_CARD_BORDER_WIDTH: int = 1
const HUD_CARD_SHADOW_SIZE: int = 6
const HUD_CARD_DEFAULT_PADDING_H: float = 12.0
const HUD_CARD_DEFAULT_PADDING_V: float = 8.0

const TOOLTIP_PADDING_PX: float = 10.0
const TOOLTIP_CORNER_RADIUS: int = 6
const TOOLTIP_BORDER_WIDTH: int = 1
const TOOLTIP_SHADOW_SIZE: int = 8

const BAR_CORNER_RADIUS: int = 5
const BAR_BORDER_WIDTH: int = 1

const BUTTON_CORNER_RADIUS: int = 6
const BUTTON_BORDER_WIDTH_NORMAL: int = 1
const BUTTON_BORDER_WIDTH_SELECTED: int = 2
const BUTTON_PADDING_H: float = 12.0
const BUTTON_PADDING_V: float = 8.0

const DEFAULT_OUTLINE_SIZE: int = 3
const HEADER_OUTLINE_SIZE: int = 4
const DEFAULT_SHADOW_OFFSET_PX: int = 1
#endregion

## Tworzy styl dla głównych okien menu (Ekwipunek, Skrzynia, Crafting) spójny z Dziennikiem Zadań.
static func create_window_stylebox(padding: float = WINDOW_DEFAULT_PADDING_PX) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = WINDOW_BG_COLOR
	style.border_color = WINDOW_BORDER_COLOR
	style.set_border_width_all(WINDOW_BORDER_WIDTH)
	style.set_corner_radius_all(WINDOW_CORNER_RADIUS)
	style.shadow_color = WINDOW_SHADOW_COLOR
	style.shadow_size = WINDOW_SHADOW_SIZE
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

## Tworzy nieinwazyjny, półprzezroczysty styl kafelka HUD (Statystyki, Zegar, Informacje o Przedmiocie, Aktywne Efekty).
static func create_hud_card_stylebox(
	padding_h: float = HUD_CARD_DEFAULT_PADDING_H,
	padding_v: float = HUD_CARD_DEFAULT_PADDING_V
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HUD_CARD_BG_COLOR
	style.border_color = HUD_CARD_BORDER_COLOR
	style.set_border_width_all(HUD_CARD_BORDER_WIDTH)
	style.set_corner_radius_all(HUD_CARD_CORNER_RADIUS)
	style.shadow_color = HUD_CARD_SHADOW_COLOR
	style.shadow_size = HUD_CARD_SHADOW_SIZE
	style.content_margin_left = padding_h
	style.content_margin_right = padding_h
	style.content_margin_top = padding_v
	style.content_margin_bottom = padding_v
	return style

## Tworzy czytelny styl dymku Tooltipa po najechaniu kursorem na slot ekwipunku.
static func create_tooltip_stylebox() -> StyleBoxFlat:
	var style: StyleBoxFlat = create_window_stylebox(TOOLTIP_PADDING_PX)
	style.set_corner_radius_all(TOOLTIP_CORNER_RADIUS)
	style.set_border_width_all(TOOLTIP_BORDER_WIDTH)
	style.shadow_size = TOOLTIP_SHADOW_SIZE
	return style

## Stylizuje pasek ProgressBar (HP / Cooldown / Wytrzymałość) zaokrąglonym tłem i kontrastowym wypełnieniem.
static func apply_progress_bar_style(
	bar: ProgressBar,
	fill_color: Color,
	corner_radius: int = BAR_CORNER_RADIUS
) -> void:
	if bar == null:
		return
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BAR_TRACK_BG_COLOR
	bg_style.border_color = BAR_BORDER_COLOR
	bg_style.set_border_width_all(BAR_BORDER_WIDTH)
	bg_style.set_corner_radius_all(corner_radius)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.border_color = BAR_FILL_HIGHLIGHT_BORDER_COLOR
	fill_style.set_border_width_all(BAR_BORDER_WIDTH)
	fill_style.set_corner_radius_all(corner_radius)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

## Nadaje przyciskowi czytelny styl RPG z podświetleniem na złoto po najechaniu lub zaznaczeniu.
static func apply_button_style(btn: Button, is_selected: bool = false) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_PRESSED_BG if is_selected else BUTTON_NORMAL_BG
	normal.border_color = BUTTON_BORDER_ACCENT if is_selected else BUTTON_BORDER_NORMAL
	normal.set_border_width_all(BUTTON_BORDER_WIDTH_SELECTED if is_selected else BUTTON_BORDER_WIDTH_NORMAL)
	normal.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	normal.content_margin_left = BUTTON_PADDING_H
	normal.content_margin_right = BUTTON_PADDING_H
	normal.content_margin_top = BUTTON_PADDING_V
	normal.content_margin_bottom = BUTTON_PADDING_V

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON_HOVER_BG
	hover.border_color = BUTTON_BORDER_ACCENT

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BUTTON_PRESSED_BG
	pressed.border_color = BUTTON_BORDER_ACCENT

	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = BUTTON_DISABLED_BG
	disabled.border_color = BUTTON_BORDER_DISABLED

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

## Poprawia czytelność etykiety tekstowej (Label) na zróżnicowanych tłach za pomocą obrysu i cienia.
static func apply_readable_label_style(
	label: Label,
	font_color: Color = Color.WHITE,
	outline_size: int = DEFAULT_OUTLINE_SIZE
) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", TEXT_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_constant_override("shadow_offset_x", DEFAULT_SHADOW_OFFSET_PX)
	label.add_theme_constant_override("shadow_offset_y", DEFAULT_SHADOW_OFFSET_PX)

## Automatycznie ukrywa tło PanelContainera, gdy znajdująca się w nim etykieta Label jest pusta lub niewidoczna.
static func bind_auto_hide_panel_to_label(
	panel: PanelContainer,
	label: Label,
	active_style: StyleBoxFlat
) -> void:
	if panel == null or label == null:
		return
	var empty_style := StyleBoxEmpty.new()
	var sync_panel_style: Callable = func() -> void:
		if not is_instance_valid(panel) or not is_instance_valid(label):
			return
		var has_content: bool = label.visible and not label.text.strip_edges().is_empty()
		panel.add_theme_stylebox_override("panel", active_style if has_content else empty_style)

	if not label.minimum_size_changed.is_connected(sync_panel_style):
		label.minimum_size_changed.connect(sync_panel_style)
	if not label.visibility_changed.is_connected(sync_panel_style):
		label.visibility_changed.connect(sync_panel_style)
	sync_panel_style.call()

## Podpina pod dowolny kontener (np. QuestTrackerUI) samodopasowujący się kafelek tła,
## który obejmuje cały blok śledzonego zadania (tytuł, licznik czasu i cele) oraz znika w 100%, gdy nic nie jest śledzone.
static func attach_auto_bounds_backdrop(
	target_root: Control,
	padding_h: float = HUD_CARD_DEFAULT_PADDING_H,
	padding_v: float = HUD_CARD_DEFAULT_PADDING_V
) -> void:
	if target_root == null or target_root.get_node_or_null("AutoBoundsBackdrop") != null:
		return
	var backdrop := _AutoBoundsBackdrop.new()
	backdrop.name = "AutoBoundsBackdrop"
	backdrop.setup(target_root, create_hud_card_stylebox(0.0, 0.0), padding_h, padding_v)
	target_root.add_child(backdrop)

## Wewnętrzny komponent śledzący rzeczywiste granice (Rect2) wszystkich widocznych elementów tekstowych
## (Label, RichTextLabel oraz ich kontenerów) wewnątrz węzła docelowego (SRP).
class _AutoBoundsBackdrop extends Panel:
	const MIN_VALID_RECT_SIZE_PX: float = 2.0

	var _target_root: Control = null
	var _pad_h: float = 12.0
	var _pad_v: float = 8.0

	func setup(target_root: Control, style: StyleBoxFlat, pad_h: float, pad_v: float) -> void:
		_target_root = target_root
		_pad_h = pad_h
		_pad_v = pad_v
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", style)
		visible = false

	func _process(_delta: float) -> void:
		if not is_instance_valid(_target_root) or not _target_root.is_visible_in_tree():
			visible = false
			return

		var has_any_visible_text: bool = false
		var merged_global_rect := Rect2()
		var container_rects: Array[Rect2] = []

		var stack: Array[Node] = [_target_root]
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			if current == self:
				continue

			if current is Label:
				var lbl: Label = current as Label
				if lbl.is_visible_in_tree() and not lbl.text.strip_edges().is_empty():
					_ensure_control_text_outline(lbl)
					var lbl_rect: Rect2 = lbl.get_global_rect()
					lbl_rect.size.x = maxf(lbl_rect.size.x, lbl.get_minimum_size().x)
					lbl_rect.size.y = maxf(lbl_rect.size.y, lbl.get_minimum_size().y)
					if lbl_rect.size.x > MIN_VALID_RECT_SIZE_PX and lbl_rect.size.y > MIN_VALID_RECT_SIZE_PX:
						merged_global_rect = lbl_rect if not has_any_visible_text else merged_global_rect.merge(lbl_rect)
						has_any_visible_text = true

			elif current is RichTextLabel:
				var rtl: RichTextLabel = current as RichTextLabel
				if rtl.is_visible_in_tree() and not rtl.get_parsed_text().strip_edges().is_empty():
					_ensure_control_text_outline(rtl)
					var rtl_rect: Rect2 = rtl.get_global_rect()
					var scale_vec: Vector2 = rtl.get_global_transform_with_canvas().get_scale()
					var content_w: float = float(rtl.get_content_width()) * absf(scale_vec.x)
					var content_h: float = float(rtl.get_content_height()) * absf(scale_vec.y)
					rtl_rect.size.x = maxf(rtl_rect.size.x, content_w)
					rtl_rect.size.y = maxf(rtl_rect.size.y, content_h)
					if rtl_rect.size.x > MIN_VALID_RECT_SIZE_PX and rtl_rect.size.y > MIN_VALID_RECT_SIZE_PX:
						merged_global_rect = rtl_rect if not has_any_visible_text else merged_global_rect.merge(rtl_rect)
						has_any_visible_text = true

			elif current is Container and current != _target_root:
				var cont: Container = current as Container
				if cont.is_visible_in_tree():
					var cont_rect: Rect2 = cont.get_global_rect()
					if cont_rect.size.x > MIN_VALID_RECT_SIZE_PX and cont_rect.size.y > MIN_VALID_RECT_SIZE_PX:
						container_rects.append(cont_rect)

			for child in current.get_children():
				stack.append(child)

		if not has_any_visible_text:
			visible = false
			return

		for c_rect in container_rects:
			merged_global_rect = merged_global_rect.merge(c_rect)

		visible = true
		var inv_scale: Vector2 = get_global_transform_with_canvas().get_scale()
		var scale_x: float = maxf(0.001, absf(inv_scale.x))
		var scale_y: float = maxf(0.001, absf(inv_scale.y))
		global_position = merged_global_rect.position - Vector2(_pad_h * scale_x, _pad_v * scale_y)
		size = (merged_global_rect.size / Vector2(scale_x, scale_y)) + Vector2(_pad_h * 2.0, _pad_v * 2.0)

	func _ensure_control_text_outline(ctrl: Control) -> void:
		if ctrl.has_meta("hud_styled"):
			return
		ctrl.set_meta("hud_styled", true)
		ctrl.add_theme_color_override("font_outline_color", UIThemeStyler.TEXT_OUTLINE_COLOR)
		ctrl.add_theme_constant_override("outline_size", UIThemeStyler.DEFAULT_OUTLINE_SIZE)
