extends Node
class_name AICombatController

var controller: AIController
var _last_weapon_index: int = -1 # Pamięta ostatnio używaną broń, -1 wymusza przeładowanie statystyk na starcie!

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller

func process_combat(delta: float) -> void:
	var entity = controller.entity
	var blackboard = controller.blackboard
	var stats = entity.interaction_and_attack_stats_script
	
	if not stats or blackboard.target == null: return
	
	stats.interaction_cooldown_process(delta)
	
	var dist = entity.global_position.distance_to(blackboard.target.global_position)
	var my_radius = entity.combat_radius if "combat_radius" in entity else 20.0
	var target_radius = blackboard.target.combat_radius if "combat_radius" in blackboard.target else 20.0
	var edge_dist = max(0.0, dist - (my_radius + target_radius))
	
	var ai_inventory = controller.get_node_or_null("AIInventoryController")
	
	# Opcja 1: AI używa Ekwipunku (Wybiera broń odpowiednią do dystansu!)
	if ai_inventory and not ai_inventory.items.is_empty():
		_select_best_weapon(ai_inventory, edge_dist)
		
		var weapon = ai_inventory.get_current_item()
		if weapon != null:
			var attack_comp = entity.get_node_or_null("AttackComponent")
			if edge_dist <= stats.get_total_range() and stats.can_attack():
				var has_los = controller.perception.can_see_target(blackboard.target)
				if attack_comp and has_los:
					attack_comp.execute_attack(entity, blackboard.target, weapon, ai_inventory, stats, has_los)
					
	# Opcja 2: Dzikie potwory bez ekwipunku (Gryzienie/Zwierzęta)
	else:
		if edge_dist <= stats.get_total_range() and stats.can_attack():
			stats.execute_attack_on_target(entity, blackboard.target)

## Funkcja decyzyjna: Wybiera broń na podstawie odległości
func _select_best_weapon(inventory: AIInventoryController, distance: float) -> void:
	var best_index = inventory.current_item_index
	
	for i in range(inventory.items.size()):
		var item = inventory.items[i]
		if item.data.components == null: continue
		for comp in item.data.components:
			# Wyciągnij broń białą, jeśli cel jest bardzo blisko (np. < 60 pikseli)
			if comp is MeleeWeaponComponent and distance < 60.0:
				best_index = i
				break
			# Wyciągnij broń dystansową, jeśli cel jest daleko
			elif comp is RangedWeaponComponent and distance >= 60.0:
				best_index = i
				break

	# NAPRAWA: Zmieniamy statystyki jeśli zmienił się indeks LUB jeśli to nasz pierwszy wybór (_last_weapon_index == -1)
	if best_index != _last_weapon_index:
		_last_weapon_index = best_index
		inventory.current_item_index = best_index
		
		var new_weapon = inventory.get_current_item()
		if new_weapon and new_weapon.data.components:
			for comp in new_weapon.data.components:
				if comp is MeleeWeaponComponent or comp is RangedWeaponComponent:
					# Synchronizacja dystansu i obrażeń
					controller.entity.interaction_and_attack_stats_script.actual_attack_data = comp.attack_data
					controller.entity.interaction_and_attack_stats_script.change_item_cooldown(comp.use_cooldown)
					print("AI załadowało statystyki broni. Nowy zasięg: ", comp.attack_data.max_range)
