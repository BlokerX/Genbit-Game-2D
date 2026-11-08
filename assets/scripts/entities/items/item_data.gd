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
) -> void:
	item_id = _item_id
	item_name = _item_name
	item_description = _item_description
	item_icon = _item_icon

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)

## Tworzy unikalną, niezależną kopię danych przedmiotu oraz jego komponentów i statystyk (AttackData),
## pozwalając na bezpieczne ulepszanie/modyfikowanie pojedynczego egzemplarza broni w locie (np. zwiększenie DMG lub zasięgu)
## BEZ klonowania w pamięci RAM ciężkich tekstur (Texture2D), dźwięków (FeedbackCue) ani scen (PackedScene)!
func create_unique_copy() -> ItemData:
	var copy: ItemData = duplicate(false) as ItemData
	copy.tags = tags.duplicate()
	if components != null:
		var cloned_components: Array[ItemComponent] = []
		for comp in components:
			if comp != null:
				cloned_components.append(comp.create_unique_copy())
		copy.components = cloned_components
	return copy
