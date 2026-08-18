class_name ItemCondition
extends Resource

## Jeśli zwróci false, komponent nie zostanie wykonany
func check_condition(_actor: Node2D, _item: ItemInstance) -> bool:
	return true
