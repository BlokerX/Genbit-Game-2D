# item_weapon.gd
extends UseableItem
class_name ItemWeapon

@export var attack_data : AttackData
@export var is_ranged : bool = false
@export var weapon_type : String = "Sword"

# Constructor
func _init(
# Argumenty ogólne (dla ItemData i UseableItem):
 _item_id : int = 1,
 _item_name : String = "Weapon",
 _item_type : String = "Weapon",
 _item_description : String = "",
 _item_is_stackable : bool = false,
 _item_max_stack_count : int = 1,
 _item_sprite : Texture2D = null,
 _max_durable : int = -1,
 _use_cooldown : float = 1.0,
 _effects : Array[Effect] = [], # Przekazujemy listę efektów (np. DamageEffect, StunEffect)
# Argumenty dla ItemWeapon:
 #_attack_range : float = 1.0,
 _attack_data : AttackData = AttackData.new(1, 0, 0.0, 1.0, 0.0),
 _is_ranged : bool = false,
 _weapon_type : String = "Sword",
 #_attack_damage : int = 1,
 #_stun_time : float = 0.0
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_max_stack_count, _item_sprite, _max_durable, _effects, _use_cooldown)
	
	# Inicjalizacja dla aktualnej klasy
	attack_data = _attack_data
	
	is_ranged = _is_ranged
	weapon_type = _weapon_type

# Zaktualizowana funkcja ataku
func affect_target(target : CharacterEntity) -> bool :
	print("Gracz atakuje przeciwnika bronią! (Obrażenia: ", attack_data.damage, ", Stun: ", attack_data.stun_time, ")")
	
	apply_all_effects(target)
	
	return true

# --- Główna funkcja wykonująca atak (Domyślnie Walka Wręcz) ---
func execute_attack(shooter: CharacterEntity, target: Node2D, weapon_instance: ItemInstance, inventory: Inventory, stats_script: InteractionAndAttackStatsComponent, spawner: Node) -> bool:
	
	# 1. Sprawdzamy zasięg
	var distance = _calculate_edge_distance(shooter, target)
	if distance > stats_script.get_total_range():
		print("Pudło! Wróg poza zasięgiem broni białej.")
		return false
		
	# 2. Wykonujemy cios!
	stats_script.execute_attack_on_target(target)
	
	# 3. Psujemy broń (jeżeli nie niezniszczalna)
	inventory.consume_durability_of_the_item()
	return true

# Pomocnicza funkcja do sprawdzania odległości (przeniesiona z gracza!)
func _calculate_edge_distance(shooter: CharacterEntity, target: Node2D) -> float:
	var shooter_radius = shooter.combat_radius if "combat_radius" in shooter else 20.0
	var target_radius = target.combat_radius if "combat_radius" in target else 20.0
	return max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_radius + target_radius))
