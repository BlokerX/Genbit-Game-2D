extends Resource
#class_name ItemData

# ==========================================
# TYLKO STAŁE DANE - ZABRONIONE ZMIENNE STANU!
# ==========================================

@export_group("Informacje Ogólne")
@export var item_id : int = 1
@export var item_name : String = "Item"
@export var item_type : String = "Item"
@export var item_description : String = ""
@export var item_icon : Texture2D 

@export_group("Stosowanie (Stackowanie)")
## Czy przedmiot jest stakowalny?
@export var item_is_stackable : bool = false
## Maksymalna ilość w JEDNYM slocie
@export var item_max_stack_count : int = 1

@export_group("Wytrzymałość")
## Maksymalna wytrzymałość (-1 oznacza przedmiot niezniszczalny)
@export var max_durable : int = -1

# Constructor
# Wszystkie zmienne MUSZĄ mieć wartości domyślne, aby edytor Godota 
# mógł tworzyć pliki .tres bez błędów.
# UWAGA: Usunięto sygnały, item_stack_count, durable oraz funkcje naprawy/niszczenia!
func _init(
	_item_id : int = 1,
	_item_name : String = "Item",
	_item_type : String = "Item",
	_item_description : String = "",
	_item_is_stackable : bool = false,
	_item_max_stack_count : int = 1,
	_item_icon : Texture2D = null,
	_max_durable : int = -1
):
	item_id = _item_id
	item_name = _item_name
	item_type = _item_type
	item_description = _item_description
	item_is_stackable = _item_is_stackable
	item_max_stack_count = _item_max_stack_count
	item_icon = _item_icon
	max_durable = _max_durable
