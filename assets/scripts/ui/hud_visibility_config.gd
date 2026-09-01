extends Node
class_name HUDVisibilityConfig

@export_group("Ukrywaj ten element HUD podczas:")
@export var hide_in_inventory: bool = true
@export var hide_in_storage: bool = true
@export var hide_in_crafting: bool = true
@export var hide_in_map: bool = true
@export var hide_in_dialogue: bool = true
@export var hide_in_pause: bool = true

func _ready() -> void:
	var parent = get_parent()
	if parent is CanvasItem:
		# Zamiast ręcznie wpisywać grupy w edytorze, ten komponent robi to sam!
		parent.add_to_group("HUD_Element")
