extends Node
class_name AttackComponent

signal spawn_projectile_requested(projectile_node: Node2D, spawn_position: Vector2)

func execute_attack(
	shooter: CharacterEntity, 
	target: Node2D, 
	weapon_instance: ItemInstance, 
	inventory: Inventory, # <--- ODBIERAMY EKWIPUNEK
	stats_script: InteractionAndAttackStatsComponent, 
	has_line_of_sight: bool
) -> bool:
	
	if not has_line_of_sight:
		print("Atak zablokowany przez ścianę!")
		return false

	# 1. ATAK BEZ BRONI (Puste ręce)
	if weapon_instance == null or weapon_instance.data == null:
		var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
		var target_rad = target.combat_radius if "combat_radius" in target else 20.0
		var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
		
		if dist > stats_script.get_total_range():
			return false
			
		print("Gracz trafia z pięści!")
		stats_script.execute_attack_on_target(target)
		return true

	# 2. ATAK Z BRONIĄ (Oddelegowanie do zasobu)
	if weapon_instance.data is ItemWeapon:
		# Przekazujemy całą władzę do pliku broni!
		return weapon_instance.data.execute_attack(shooter, target, weapon_instance, inventory, stats_script, self)
		
	return false
