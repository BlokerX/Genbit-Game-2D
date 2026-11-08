class_name EquippableComponent
extends ItemComponent
## Pozwala założyć przedmiot na dedykowany slot pancerza/akcesoriów i zapewnia pasywne wzmocnienia.

enum EquipSlot { NONE, HEAD, CHEST, LEGS, BOOTS, BACKPACK, ACCESSORY, AMULET }

@export_category("Ekwipunek")
## Zdefiniuj gdzie przedmiot ma być założony.
@export var equip_slot_type: EquipSlot = EquipSlot.NONE

## Efekty/Buffy nakładane, dopóki przedmiot jest noszony na slocie wyposażenia.
@export var passive_buffs: Array[Effect] = []

func execute(_actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	print("Próbuję założyć przedmiot na slot o ID: ", equip_slot_type)

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	var text: String = "Zakładany na: " + str(EquipSlot.keys()[equip_slot_type]) + "\n"
	if not passive_buffs.is_empty():
		for buff in passive_buffs:
			if buff != null:
				text += "- Pasywnie: " + buff.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = "Zakładany na: " + str(EquipSlot.keys()[equip_slot_type]) + "\n"
	if is_advanced and passive_buffs.size() > 0:
		text += "Ilość Buffów Pasywnych: " + str(passive_buffs.size()) + "\n"
		for buff in passive_buffs:
			if buff != null:
				text += "  - " + buff.effect_name + "\n"
	return text
