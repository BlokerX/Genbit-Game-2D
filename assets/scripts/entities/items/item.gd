extends Node

class_name Item

#region General informations and sprite

@export var item_id : int = 1
@export var item_name : String = "Item"

@export var item_type : String = "Item"

@export var item_description : String

@export var item_is_stackable : bool
@export var item_stack_count : int = 1

@export var item_sprite : Sprite2D

#endregion

#region Durability
@export var durable : int = -1
@export var max_durable : int = -1

func reduce_durability(points : int = 1) -> void :
	durable -= points
	check_durable()

func check_durable() -> bool :
	if durable == 0 :
		item_destroy()
		return false
	return true

#endregion

# Constructor
func _init(
# Argumenty dla aktualnego obiektu:
 _item_id : int,
 _item_name : String,
 _item_type : String,
 _item_description : String,
 _item_is_stackable : bool,
 _item_stack_count : int,
 _item_sprite : Sprite2D,
 _durable : int,
 _max_durable : int 
) :
	item_id = _item_id
	item_name = _item_name
	item_type = _item_type
	item_description = _item_description
	item_is_stackable = _item_is_stackable
	item_stack_count = _item_stack_count
	item_sprite = _item_sprite
	durable = _durable
	max_durable = _max_durable

# Destructor function
func item_destroy():
	# Usuwa ten węzeł (Node) oraz wszystkie jego dzieci na koniec obecnej klatki
	queue_free()
