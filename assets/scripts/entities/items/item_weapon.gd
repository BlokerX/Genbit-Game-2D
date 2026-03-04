extends Item

class_name ItemWeapon

@export var attack_range : float = 1

@export var is_ranged : bool

@export var attack_damage : int = 1

@export var weapon_type : String

# Constructor
func _init(
# Argumenty dla rodzica:
 _item_id : int,
 _item_name : String,
 # _item_type : String = Weapon,
 _item_description : String,
 _item_is_stackable : bool,
 _item_stack_count : int,
 _item_sprite : Sprite2D,
 _durable : int,
 _max_durable : int,
# Argumenty dla aktualnego obiektu:
 _attack_range : float,
 _is_ranged : bool,
 _attack_damage : int,
 _weapon_type : String
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, "Weapon", _item_description, _item_is_stackable, _item_stack_count, _item_sprite, _durable, _max_durable)
	
	# Inicjalizacja dla aktualnej klasy
	attack_range = _attack_range
	is_ranged = _is_ranged
	attack_damage = _attack_damage
	weapon_type = _weapon_type
