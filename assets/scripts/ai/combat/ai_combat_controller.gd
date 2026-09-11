extends Node
class_name AICombatController

var controller: AIController
var _last_weapon_index: int = -1 

@export_category("Zdolności Specjalne")
@export var abilities: Array[AIAbility] = []

var _ability_cooldowns: Dictionary = {}
var is_casting_ability: bool = false # <--- NOWA ZMIENNA

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	for ability in abilities:
		if ability != null:
			_ability_cooldowns[ability] = 0.0

func process_combat(delta: float) -> void:
	var entity = controller.entity
	var blackboard = controller.blackboard
	var stats = entity.interaction_and_attack_stats_script
	
	# Jeśli AI rzuca umiejętność, całkowicie ODCIKAJ ruch i zwykłe ataki
	if is_casting_ability:
		blackboard.want_to_move = false
		if entity.movement_universal_script:
			entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, Vector2.ZERO)
		return
		
	if not stats or blackboard.target == null: return
	
	stats.interaction_cooldown_process(delta)
	_process_ability_cooldowns(delta)
	
	var dist = entity.global_position.distance_to(blackboard.target.global_position)
	var my_radius = entity.combat_radius if "combat_radius" in entity else 20.0
	var target_radius = blackboard.target.combat_radius if "combat_radius" in blackboard.target else 20.0
	var edge_dist = max(0.0, dist - (my_radius + target_radius))
	
	# 1. SPRAWDZANIE ZDOLNOŚCI
	for ability in abilities:
		if ability == null: continue
		if _ability_cooldowns[ability] <= 0.0 and ability.check_conditions(entity, blackboard.target, edge_dist):
			ability.execute(entity, blackboard.target)
			_ability_cooldowns[ability] = ability.cooldown
			return 
			
	# 2. ZWYKŁY ATAK
	var ai_inventory = controller.get_node_or_null("AIInventoryController")
	var switch_dist = 60.0
	if controller.behavior_profile and "melee_switch_distance" in controller.behavior_profile:
		switch_dist = controller.behavior_profile.melee_switch_distance
		
	if ai_inventory and not ai_inventory.items.is_empty():
		_select_best_weapon(ai_inventory, edge_dist, switch_dist)
		var weapon = ai_inventory.get_current_item()
		if weapon != null:
			var attack_comp = entity.get_node_or_null("AttackComponent")
			if edge_dist <= stats.get_total_range() and stats.can_attack():
				var has_los = controller.perception.can_see_target(blackboard.target)
				if attack_comp and has_los:
					attack_comp.execute_attack(entity, blackboard.target, weapon, ai_inventory, stats, has_los)
	else:
		if edge_dist <= stats.get_total_range() and stats.can_attack():
			stats.execute_attack_on_target(entity, blackboard.target)

func _process_ability_cooldowns(delta: float) -> void:
	for ability in _ability_cooldowns.keys():
		if _ability_cooldowns[ability] > 0.0:
			_ability_cooldowns[ability] -= delta

func _select_best_weapon(inventory: AIInventoryController, distance: float, switch_dist: float) -> void:
	var best_index = inventory.current_item_index
	for i in range(inventory.items.size()):
		var item = inventory.items[i]
		if item.data.components == null: continue
		for comp in item.data.components:
			if comp is MeleeWeaponComponent and distance < switch_dist:
				best_index = i
				break
			elif comp is RangedWeaponComponent and distance >= switch_dist:
				best_index = i
				break

	if best_index != _last_weapon_index:
		_last_weapon_index = best_index
		inventory.current_item_index = best_index
		var new_weapon = inventory.get_current_item()
		if new_weapon and new_weapon.data.components:
			for comp in new_weapon.data.components:
				if comp is MeleeWeaponComponent or comp is RangedWeaponComponent:
					controller.entity.interaction_and_attack_stats_script.actual_attack_data = comp.attack_data
					controller.entity.interaction_and_attack_stats_script.change_item_cooldown(comp.use_cooldown)
