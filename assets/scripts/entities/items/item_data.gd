extends Resource
class_name ItemData

#region General informations and sprite
@export var item_id : int = 1
@export var item_name : String = "Item"

@export var item_type : String = "Item"

@export var item_description : String = ""

@export var item_is_stackable : bool = false
@export var item_stack_count : int = 1
@export var item_max_stack_count : int = 1

# Używamy Texture2D zamiast Sprite2D do przechowywania grafiki w danych
@export var item_icon : Texture2D 
#endregion

#region Durability
@export var durable : int = -1
@export var max_durable : int = -1

func reduce_durability(points : int = 1) -> void:
	if durable > 0:
		durable -= points
		
# Funkcja nie usuwa już sama siebie, tylko informuje o swoim stanie
func is_broken() -> bool:
	if max_durable > 0 and durable <= 0:
		return true
	return false
#endregion

# Constructor
# Wszystkie zmienne MUSZĄ mieć wartości domyślne, aby edytor Godota 
# mógł tworzyć pliki .tres bez błędów.
func _init(
	_item_id : int = 1,
	_item_name : String = "Item",
	_item_type : String = "Item",
	_item_description : String = "",
	_item_is_stackable : bool = false,
	_item_stack_count : int = 1,
	_item_max_stack_count : int = 1,
	_item_icon : Texture2D = null,
	_durable : int = -1,
	_max_durable : int = -1
):
	item_id = _item_id
	item_name = _item_name
	item_type = _item_type
	item_description = _item_description
	item_is_stackable = _item_is_stackable
	item_stack_count = _item_stack_count
	item_max_stack_count = _item_max_stack_count
	item_icon = _item_icon
	durable = _durable
	max_durable = _max_durable
