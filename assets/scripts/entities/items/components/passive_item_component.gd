class_name PassiveItemComponent
extends ItemComponent
## Komponent przedmiotów pasywnych (talizmany, relikty), które działają już przez samo posiadanie w plecaku lub trzymanie w dłoni.

enum PassiveRequirement { INVENTORY, HELD }

@export_category("Pasywne Działanie")
## Gdzie przedmiot musi się znajdować, by pasywka działała?
@export var requirement: PassiveRequirement = PassiveRequirement.INVENTORY
@export var passive_buffs: Array[Effect] = []
## Jeśli true, efekty stackują się z każdą kolejną sztuką przedmiotu.
## Jeśli false, liczy się tylko fakt posiadania minimum 1 sztuki.
@export var stack_effects_with_amount: bool = false

func _get_requirement_label() -> String:
	return "W dłoni" if requirement == PassiveRequirement.HELD else "W ekwipunku"

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	if passive_buffs.is_empty():
		return ""
	var text: String = "Pasywne (" + _get_requirement_label() + "):\n"
	for buff in passive_buffs:
		if buff != null:
			text += "- " + buff.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	if passive_buffs.is_empty():
		return ""
	var text: String = ""
	if is_advanced:
		text += "Działanie Pasywne (" + _get_requirement_label() + "):\n"
		if stack_effects_with_amount:
			text += "Kumuluje się z ilością: Tak\n"
		for buff in passive_buffs:
			if buff != null:
				text += "  - " + buff.effect_name + "\n"
	else:
		text += "Działanie Pasywne: Tak (" + _get_requirement_label() + ")\n"
	return text
