extends Node

class_name Item

@export var item_id : int
@export var item_name : String

@export var item_is_stackable : bool
@export var item_stack_count : int

@export var item_type : String
@export var item_description : int

@export var item_sprite : Sprite2D

func item_destroy():
	# Usuwa ten węzeł (Node) oraz wszystkie jego dzieci na koniec obecnej klatki
	queue_free()
