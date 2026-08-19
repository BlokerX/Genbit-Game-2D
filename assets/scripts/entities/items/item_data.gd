class_name ItemData 
extends Resource

@export_group("Informacje Ogólne")
@export var item_id : StringName = &"default_item"
@export var item_name : String = "Item"
@export var item_description : String = ""
@export var item_icon : Texture2D

@export_group("System Tagów")
## Tagi służące do wyszukiwania ogólnych typów przedmiotów (np. "material_wood", "weapon_sword")
@export var tags: Array[StringName] = []

@export_group("Komponenty Zachowań")
@export var components : Array[ItemComponent] = []

func _init(
	_item_id : StringName = &"default_item",
	_item_name : String = "Item",
	_item_description : String = "",
	_item_icon : Texture2D = null
):
	item_id = _item_id
	item_name = _item_name
	item_description = _item_description
	item_icon = _item_icon

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
