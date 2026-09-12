extends Node
class_name AttackComponent

signal spawn_projectile_requested(projectile_node: Node2D, spawn_position: Vector2)

func execute_attack(shooter: CharacterEntity, target: Node2D, weapon_instance: ItemInstance, inventory: Variant, stats_script: InteractionAndAttackStatsComponent, has_line_of_sight: bool) -> bool:
	if not has_line_of_sight:
		return false 

	# 1. SPRAWDZENIE CZY TRZYMANY PRZEDMIOT TO FAKTYCZNIE BROŃ LUB MATERIAŁ WYBUCHOWY
	var has_weapon_component = false
	if weapon_instance != null and weapon_instance.data != null and weapon_instance.data.components != null:
		for comp in weapon_instance.data.components:
			if comp is MeleeWeaponComponent or comp is RangedWeaponComponent or comp is ThrowableComponent or comp is PlaceableComponent:
				has_weapon_component = true
				break

	if weapon_instance == null or weapon_instance.data == null or not has_weapon_component:
		var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
		var target_rad = target.combat_radius if "combat_radius" in target else 20.0
		var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
		
		if dist > stats_script.get_total_range(): return false
		stats_script.execute_attack_on_target(shooter, target)
		return true 

	# 2. WYKONANIE ATAKU W ZALEŻNOŚCI OD KOMPONENTU
	for comp in weapon_instance.data.components:
		if comp is MeleeWeaponComponent:
			var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
			var target_rad = target.combat_radius if "combat_radius" in target else 20.0
			var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
			if dist > stats_script.get_total_range(): return false
			comp.execute(shooter, target, weapon_instance)
			return true 
			
		elif comp is RangedWeaponComponent:
			comp.execute(shooter, target, weapon_instance)
			return true 
			
		elif comp is ThrowableComponent:
			comp.execute(shooter, target, weapon_instance)
			return true
			
		elif comp is PlaceableComponent:
			comp.execute(shooter, target, weapon_instance)
			return true
			
	return false
