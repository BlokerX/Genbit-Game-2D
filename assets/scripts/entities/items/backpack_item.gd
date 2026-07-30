extends ItemData
class_name BackpackItem

@export_category("Backpack Settings")
## Liczba dodatkowych miejsc, o które plecak powiększa ekwipunek
@export var extra_slots_count: int = 5

func _init(
	_item_id : int = 1,
	_item_name : String = "Plecak",
	_item_type : String = "Backpack",
	_item_description : String = "Zwiększa pojemność ekwipunku po założeniu.",
	_item_is_stackable : bool = false,
	_item_max_stack_count : int = 1,
	_item_icon : Texture2D = null,
	_max_durable : int = -1,
	_extra_slots : int = 5
) -> void:
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_max_stack_count, _item_icon, _max_durable)
	extra_slots_count = _extra_slots
