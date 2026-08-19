extends Node
class_name AttackComponent

signal spawn_projectile_requested(projectile_node: Node2D, spawn_position: Vector2)

func execute_attack(
	shooter: CharacterEntity, 
	target: Node2D, 
	weapon_instance: ItemInstance, 
	inventory: Inventory, 
	stats_script: InteractionAndAttackStatsComponent, 
	has_line_of_sight: bool
) -> bool:
	if not has_line_of_sight:
		print("Atak zablokowany przez ścianę!")
		return false 

	# --- 1. SPRAWDZENIE CZY TRZYMANY PRZEDMIOT TO FAKTYCZNIE BROŃ ---
	var has_weapon_component = false
	if weapon_instance != null and weapon_instance.data != null and weapon_instance.data.components != null:
		for comp in weapon_instance.data.components:
			if comp is MeleeWeaponComponent or comp is RangedWeaponComponent:
				has_weapon_component = true
				break

	# Jeśli nic nie ma LUB to co trzyma nie jest bronią (np. miksturka, drewno) -> Atakujemy pięścią!
	if weapon_instance == null or weapon_instance.data == null or not has_weapon_component:
		var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
		var target_rad = target.combat_radius if "combat_radius" in target else 20.0
		var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
		
		if dist > stats_script.get_total_range():
			return false
			
		print("Gracz trafia pięścią (używając przedmiotu niespecjalizowanego)!")
		stats_script.execute_attack_on_target(target)
		return true 

	# 2. ATAK Z BRONI (Skoro ma komponent broni, delegujemy do klocków ECS)
	for comp in weapon_instance.data.components:
		if comp is MeleeWeaponComponent:
			var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
			var target_rad = target.combat_radius if "combat_radius" in target else 20.0
			var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
			if dist > stats_script.get_total_range():
				print("Pudo! Wrog poza zasięgiem broni białej.")
				return false
			comp.execute(shooter, target, weapon_instance)
			return true 
		elif comp is RangedWeaponComponent:
			comp.execute(shooter, target, weapon_instance)
			return true 

	return false
