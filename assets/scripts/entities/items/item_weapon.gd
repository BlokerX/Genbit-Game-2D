extends UseableItem

class_name ItemWeapon

@export var attack_range : float = 1.0

@export var is_ranged : bool = false

@export var weapon_type : String = "Sword"

@export var attack_damage : int = 1

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
 _effects : Array[Effect] = [], # Przekazujemy listę efektów (np. DamageEffect, StunEffect)
# Argumenty dla ItemWeapon:
 _attack_range : float = 1.0,
 _is_ranged : bool = false,
 _weapon_type : String = "Sword",
 _attack_damage : int = 1,
 _stun_time : float = 0.0
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_stack_count, _item_max_stack_count, _item_sprite, _durable, _max_durable, _effects, _use_cooldown)
	
	# Inicjalizacja dla aktualnej klasy
	attack_range = _attack_range
	is_ranged = _is_ranged
	weapon_type = _weapon_type
	
	attack_damage = _attack_damage
	stun_time = _stun_time
	

# Zaktualizowana funkcja ataku
func affect_target(target : CharacterBody2D) -> bool :
	# Sprawdzenie cooldownu z klasy UseableItem
	if !super(target) :
		print("Atak ma cooldowna!")
		return false
	
	print("Gracz atakuje przeciwnika bronią! (Obrażenia: ", attack_damage, ", Stun: ", stun_time, ")")
	
	# 1. Tworzymy i nakładamy efekt obrażeń na żywo, z aktualnymi statystykami
	var damage_effect = DamageEffect.new(attack_damage)
	damage_effect.apply_effect(target)
	
	# 2. Tworzymy i nakładamy efekt ogłuszenia (tylko jeśli broń faktycznie ma stun)
	if stun_time > 0.0:
		var stun_effect = StunEffect.new(stun_time)
		stun_effect.apply_effect(target)
		
	# 3. (Opcjonalnie) Jeśli masz inne efekty dodane ręcznie w Inspektorze do tablicy 'effects',
	# też możemy je tutaj wywołać:
	apply_all_effects(target)
	
	# Rozpocznyna cooldowna
	use()
	
	return true
