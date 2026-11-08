extends Node
class_name HUDVisibilityController
## Kontroler płynnie wygaszający i przywracający elementy z grupy HUD_Element na podstawie ich HUDVisibilityConfig.

const HUD_FADE_DURATION_SEC: float = 0.25
const VISIBLE_ALPHA: float = 1.0
const HIDDEN_ALPHA: float = 0.0

var _hud_tween: Tween

func _ready() -> void:
	EventBus.hud_visibility_requested.connect(_update_hud_visibility)

func _update_hud_visibility() -> void:
	if _hud_tween and _hud_tween.is_valid():
		_hud_tween.kill()

	_hud_tween = create_tween().set_parallel(true)
	_hud_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hud_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for element in get_tree().get_nodes_in_group(HUDVisibilityConfig.HUD_ELEMENT_GROUP):
		if not element is CanvasItem:
			continue

		var should_hide: bool = false
		var config: HUDVisibilityConfig = element.get_node_or_null("HUDVisibilityConfig") as HUDVisibilityConfig

		if config != null:
			should_hide = config.should_hide_for_menus(EventBus.active_menus)
		else:
			should_hide = EventBus.is_any_menu_open()

		var target_alpha: float = HIDDEN_ALPHA if should_hide else VISIBLE_ALPHA
		_hud_tween.tween_property(element, "modulate:a", target_alpha, HUD_FADE_DURATION_SEC)

		if element is Control:
			var ctrl: Control = element as Control
			if should_hide:
				# Zapisujemy filtr myszy tuż przed ukryciem elementu
				if not ctrl.has_meta("original_mouse_filter"):
					ctrl.set_meta("original_mouse_filter", ctrl.mouse_filter)
				ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				# Przywracamy filtr myszy TYLKO wtedy, gdy element był wcześniej ukryty przez ten kontroler!
				if ctrl.has_meta("original_mouse_filter"):
					ctrl.mouse_filter = int(ctrl.get_meta("original_mouse_filter")) as Control.MouseFilter
					ctrl.remove_meta("original_mouse_filter")
