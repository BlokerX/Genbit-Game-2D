extends Item

class_name ItemDurable

@export var durable : float

@export var max_durable : float

func check_durable() -> bool :
	if durable <= max_durable :
		item_destroy()
		return false
	return true
