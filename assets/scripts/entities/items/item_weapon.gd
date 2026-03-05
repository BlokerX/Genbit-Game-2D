extends UseableItem

class_name ItemWeapon

@export var attack_range : float = 1.0

@export var is_ranged : bool = false

@export var attack_damage : int = 1

@export var weapon_type : String = "Sword"

@export var stun_time : float = 0.0

# Constructor
func _init(
# Argumenty ogólne (dla ItemData i UseableItem):
 _item_id : int = 1,
 _item_name : String = "Weapon",
 _item_type : String = "Weapon",
 _item_description : String = "",
 _item_is_stackable : bool = false,
 _item_stack_count : int = 1,
 _item_max_stack_count : int = 1,
 _item_sprite : Texture2D = null,
 _durable : int = -1,
 _max_durable : int = -1,
 _use_cooldown : float = 1.0,
# Argumenty dla ItemWeapon:
 _attack_range : float = 1.0,
 _is_ranged : bool = false,
 _attack_damage : int = 1,
 _weapon_type : String = "Sword",
 _stun_time : float = 0.0
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_stack_count, _item_max_stack_count, _item_sprite, _durable, _max_durable, _use_cooldown)
	
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
	
	print("Gracz atakuje przeciwnika bronią!")
	# Wywołanie metod na targecie pozostaje bez zmian
	target.health_stats_script.take_damage(attack_damage)
	target.attack_stats_script.apply_stun(stun_time)
