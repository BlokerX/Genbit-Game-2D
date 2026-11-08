extends Node
class_name HUDVisibilityConfig
## Komponent konfiguracyjny określający, podczas jakich otwartych okien menu dany element HUD ma być ukrywany.

const HUD_ELEMENT_GROUP: StringName = &"HUD_Element"

@export_group("Ukrywaj ten element HUD podczas:")
@export var hide_in_inventory: bool = true
@export var hide_in_storage: bool = true
@export var hide_in_crafting: bool = true
@export var hide_in_map: bool = true
@export var hide_in_dialogue: bool = true
@export var hide_in_quest_log: bool = true
@export var hide_in_pause: bool = true

func _ready() -> void:
	var parent: Node = get_parent()
	if parent is CanvasItem:
		# Zamiast ręcznie wpisywać grupy w edytorze, ten komponent robi to sam!
		parent.add_to_group(HUD_ELEMENT_GROUP)

## Sprawdza (zgodnie z zasadą Information Expert / OCP), czy element powinien zostać ukryty dla aktualnie aktywnych menu.
func should_hide_for_menus(active_menus: Dictionary) -> bool:
	return (
		(hide_in_inventory and active_menus.get(EventBus.MENU_INVENTORY, false))
		or (hide_in_storage and active_menus.get(EventBus.MENU_STORAGE, false))
		or (hide_in_crafting and active_menus.get(EventBus.MENU_CRAFTING, false))
		or (hide_in_map and active_menus.get(EventBus.MENU_MAP, false))
		or (hide_in_dialogue and active_menus.get(EventBus.MENU_DIALOGUE, false))
		or (hide_in_pause and active_menus.get(EventBus.MENU_PAUSE, false))
		or (hide_in_quest_log and active_menus.get(EventBus.MENU_QUEST_LOG, false))
	)
