extends Effect
class_name GiveItemEffect

@export var item_to_give: ItemData
@export var amount: int = 1

func _init() -> void:
	effect_name = "Give Item"

func apply_effect(target: Node2D) -> bool:
	if item_to_give == null: 
		return false
	
	# Znowu korzystamy z faktu, że przekazujemy interaktora do Managera
	if target.has_method("get_inventory"):
		var inv = target.get_inventory()
		# Wywołujemy bezpieczne dawanie itemu z Twojego inventory.gd
		var leftovers = inv.add_item(item_to_give, amount)
		
		# Opcjonalnie: Jeśli plecak był pełen i został nadmiar, rzucamy na podłogę
		if leftovers > 0:
			var unique_data = item_to_give.duplicate(true)
			var leftover_instance = ItemInstance.new(unique_data, leftovers)
			inv.item_dropped.emit(leftover_instance, false)
			
		print("Dialog: Wręczono ", amount, "x ", item_to_give.item_name)
		return true
		
	return false
