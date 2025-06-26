extends CharacterBody2D # Resource

@export var health : int = 100
@export var max_health : int = 100

func _ready():
	pass

func get_damage(_health : int) :
	health -= _health
	if health < 0 :
		health = 0

func heal(_health : int) :
	health += _health
	if health > max_health :
		health = max_health
