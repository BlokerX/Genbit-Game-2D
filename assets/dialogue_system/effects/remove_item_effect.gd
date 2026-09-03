extends Effect
class_name RemoveItemEffect

@export var item_to_remove: ItemData
@export var amount: int = 1

func _init() -> void:
	effect_name = "Remove Item"

func apply_effect(target: Node2D) -> bool:
	if item_to_remove == null: 
		return false
		
	if target.has_method("get_inventory"):
		var inv = target.get_inventory()
		# Sprawdzamy dla pewności, czy gracz ma przedmiot, a potem go niszczymy
		if inv.has_items(item_to_remove.item_id, amount):
			inv.consume_ingredients(item_to_remove.item_id, amount)
			print("Dialog: Zabrano ", amount, "x ", item_to_remove.item_name)
			return true
			
	return false
