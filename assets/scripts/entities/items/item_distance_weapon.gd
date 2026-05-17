extends ItemWeapon
class_name ItemDistanceWeapon

@export_category("Distance Weapon Settings")

## Tekstura pocisku wystrzeliwanego przez tę konkretną broń
@export var projectile_texture : Texture2D

## Prędkość z jaką porusza się pocisk
@export var projectile_speed : float = 500.0

## Czas życia pocisku w sekundach (zanim sam zniknie, jeśli w nic nie trafi)
@export var projectile_lifetime : float = 2.0

## Constructor
# Constructor
func _init(
	# --- Argumenty z UseableItem i ItemData ---
	_item_id : int = 1,
	_item_name : String = "Distance Weapon",
	_item_type : String = "Weapon",
	_item_description : String = "",
	_item_is_stackable : bool = false,
	_item_stack_count : int = 1,
	_item_max_stack_count : int = 1,
	_item_sprite : Texture2D = null,
	_durable : int = -1,
	_max_durable : int = -1,
	_use_cooldown : float = 1.0,
	_effects : Array[Effect] = [],
	# --- Argumenty z ItemWeapon ---
	_attack_data : AttackData = AttackData.new(1, 0, 0.0, 1.0, 0.0),
	_weapon_type : String = "Bow",
	# --- Nowe argumenty dla ItemDistanceWeapon ---
	_projectile_texture : Texture2D = null,
	_projectile_speed : float = 500.0,
	_projectile_lifetime : float = 2.0
) :
	
	# 1. Wywołanie konstruktora _init() z klasy ItemWeapon.
	# Zwróć uwagę na przedostatni argument: przekazujemy 'true', 
	# aby wymusić is_ranged = true w klasie bazowej.
	super(
		_item_id, 
		_item_name, 
		_item_type, 
		_item_description, 
		_item_is_stackable, 
		_item_stack_count, 
		_item_max_stack_count, 
		_item_sprite, 
		_durable, 
		_max_durable, 
		_use_cooldown, 
		_effects, 
		_attack_data, 
		true, # Zawsze true dla broni dystansowej
		_weapon_type
	)
	
	# 2. Inicjalizacja dla aktualnej klasy (ItemDistanceWeapon)
	projectile_texture = _projectile_texture
	projectile_speed = _projectile_speed
	projectile_lifetime = _projectile_lifetime
