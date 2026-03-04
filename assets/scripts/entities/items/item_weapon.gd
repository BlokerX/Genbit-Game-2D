extends UseableItem

class_name ItemWeapon

@export var attack_range : float = 1

@export var is_ranged : bool

@export var attack_damage : int = 1

@export var weapon_type : String

@export var stun_time : float

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
 _weapon_type : String,
 _use_cooldown : float,
 _stun_time : float
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, "Weapon", _item_description, _item_is_stackable, _item_stack_count, _item_sprite, _durable, _max_durable, _use_cooldown)
	
	# Inicjalizacja dla aktualnej klasy
	attack_range = _attack_range
	is_ranged = _is_ranged
	attack_damage = _attack_damage
	weapon_type = _weapon_type
	stun_time = _stun_time

func attack(target : CharacterBody2D) -> void :
	if !super.use() :
		print("Atak ma cooldowna!")
		return
	
	target.health_stats_script.take_damage(attack_damage)
	target.attack_stats_script.apply_stun(stun_time)
