extends ItemCondition
class_name HasItemCondition

@export var required_item: ItemData
@export var required_amount: int = 1

func check_condition(actor: Node2D, _item: ItemInstance) -> bool:
	if required_item == null: 
		return true
	
	# Duck Typing: sprawdzamy czy aktor ma ekwipunek
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		# Wywołujemy funkcję z Twojego inventory.gd!
		return inv.has_items(required_item.item_id, required_amount)
	
	return false
