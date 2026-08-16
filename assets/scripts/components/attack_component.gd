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

	# 2. ATAK Z BRONIĄ (Oddelegowanie do Komponentów ECS)
	if weapon_instance.data.components != null:
		for comp in weapon_instance.data.components:
			
			# A) Obsługa Broni Białej
			if comp is MeleeWeaponComponent:
				# TWOJA ORYGINALNA MATEMATYKA DYSTANSU (Skopiowana z ataku pustymi rękami)
				var shooter_rad = shooter.combat_radius if "combat_radius" in shooter else 20.0
				var target_rad = target.combat_radius if "combat_radius" in target else 20.0
				var dist = max(0.0, shooter.global_position.distance_to(target.global_position) - (shooter_rad + target_rad))
				
				if dist > stats_script.get_total_range():
					print("Pudło! Wróg poza zasięgiem broni białej.")
					return false
					
				# Cios jest w zasięgu - zlecamy go komponentowi
				comp.execute(shooter, target, weapon_instance)
				return true
				
			# B) Obsługa Broni Dystansowej (Strzał)
			elif comp is RangedWeaponComponent:
				# Broń dystansowa sama zajmuje się liczeniem dystansu lotu pocisku
				comp.execute(shooter, target, weapon_instance)
				return true
		
	return false
