extends Node
class_name HUDVisibilityController

const HUD_FADE_DURATION_SEC: float = 0.25

var _hud_tween: Tween

func _ready() -> void:
	EventBus.hud_visibility_requested.connect(_update_hud_visibility)

func _update_hud_visibility() -> void:
	if _hud_tween and _hud_tween.is_valid():
		_hud_tween.kill()

	_hud_tween = create_tween().set_parallel(true)
	_hud_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hud_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for element in get_tree().get_nodes_in_group("HUD_Element"):
		if not element is CanvasItem:
			continue

		var should_hide: bool = false
		var config: HUDVisibilityConfig = element.get_node_or_null("HUDVisibilityConfig") as HUDVisibilityConfig

		if config != null:
			should_hide = (
				(config.hide_in_inventory and EventBus.active_menus[EventBus.MENU_INVENTORY])
				or (config.hide_in_storage and EventBus.active_menus[EventBus.MENU_STORAGE])
				or (config.hide_in_crafting and EventBus.active_menus[EventBus.MENU_CRAFTING])
				or (config.hide_in_map and EventBus.active_menus[EventBus.MENU_MAP])
				or (config.hide_in_dialogue and EventBus.active_menus[EventBus.MENU_DIALOGUE])
				or (config.hide_in_pause and EventBus.active_menus[EventBus.MENU_PAUSE])
				or (config.hide_in_quest_log and EventBus.active_menus[EventBus.MENU_QUEST_LOG])
			)
		else:
			should_hide = EventBus.is_any_menu_open()

		_hud_tween.tween_property(element, "modulate:a", 0.0 if should_hide else 1.0, HUD_FADE_DURATION_SEC)

		if element is Control:
			var ctrl: Control = element as Control
			if should_hide:
				# Zapisujemy filtr myszy tuż przed ukryciem elementu
				if not ctrl.has_meta("original_mouse_filter"):
					ctrl.set_meta("original_mouse_filter", ctrl.mouse_filter)
				ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				# Przywracamy filtr myszy TYLKO wtedy, gdy element był wcześniej ukryty przez ten kontroler!
				# Chroni to rozłożoną Minimapę przed nadpisaniem MOUSE_FILTER_STOP przez stare MOUSE_FILTER_IGNORE.
				if ctrl.has_meta("original_mouse_filter"):
					ctrl.mouse_filter = int(ctrl.get_meta("original_mouse_filter"))
					ctrl.remove_meta("original_mouse_filter")
