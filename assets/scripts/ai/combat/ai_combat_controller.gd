extends Node
class_name AICombatController
## Kontroler walki AI zarządzający rzucaniem zdolności specjalnych (AIAbility), doborem broni i wykonywaniem ataków.

const DEFAULT_COMBAT_RADIUS_PX: float = 20.0
const DEFAULT_MELEE_SWITCH_DISTANCE_PX: float = 60.0
const HESITATION_MIN_DELAY_SEC: float = 0.3
const HESITATION_MAX_DELAY_SEC: float = 1.2
const WEAPON_EVAL_INTERVAL_SEC: float = 0.15

var controller: AIController
var _last_weapon_index: int = -1 
var _weapon_eval_timer: float = 0.0
var _ai_inventory: AIInventoryController = null
var _attack_component: AttackComponent = null

@export_category("Zdolności Specjalne")
@export var abilities: Array[AIAbility] = []
var _ability_cooldowns: Dictionary = {}
var is_casting_ability: bool = false

## Licznik czasu spędzonego w aktywnej walce (używany przez first_cast_delay w zdolnościach).
var time_in_combat: float = 0.0

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	_weapon_eval_timer = randf_range(0.0, WEAPON_EVAL_INTERVAL_SEC)
	if controller != null:
		_ai_inventory = controller.get_node_or_null("AIInventoryController") as AIInventoryController
		if is_instance_valid(controller.entity):
			_attack_component = controller.entity.get_node_or_null("AttackComponent") as AttackComponent

	for ability in abilities:
		if ability != null:
			_ability_cooldowns[ability] = 0.0

func process_combat(delta: float) -> void:
	if controller == null or not is_instance_valid(controller.entity):
		return

	var entity: CharacterEntity = controller.entity
	var blackboard: AIBlackboard = controller.blackboard
	var stats: InteractionAndAttackStatsComponent = entity.interaction_and_attack_stats_script

	# Zegary umiejętności tykają, nawet jeśli wróg odpoczywa
	_process_ability_cooldowns(delta)
	if stats:
		stats.interaction_cooldown_process(delta)

	# Jeśli zgubiliśmy cel, resetujemy czas walki
	if not stats or blackboard.target == null or not is_instance_valid(blackboard.target): 
		time_in_combat = 0.0
		return

	# AI aktywnie widzi cel - odliczamy czas walki!
	time_in_combat += delta

	var edge_dist: float = CharacterEntity.get_edge_distance_between(entity, blackboard.target)

	# 1. SPRAWDZANIE ZDOLNOŚCI SPECJALNYCH
	var ability_casted_this_frame: bool = false

	for ability in abilities:
		if ability == null:
			continue

		if time_in_combat < ability.first_cast_delay:
			continue

		if is_casting_ability and not ability.ignore_global_cast_lock:
			continue

		if _ability_cooldowns.get(ability, 0.0) <= 0.0 and ability.check_conditions(entity, blackboard.target, edge_dist):
			if randf() <= ability.cast_chance:
				if ability.feedback_cue != null:
					GameFeedback.play_cue(
						ability.feedback_cue, entity.character_sprite, entity.global_position, entity
					)
				ability.execute(entity, blackboard.target)
				_ability_cooldowns[ability] = ability.cooldown
				ability_casted_this_frame = true

				if not ability.ignore_global_cast_lock:
					break
			else:
				# AI "zawahało się" przed atakiem. Spróbuje ponownie za krótką, losową chwilę.
				_ability_cooldowns[ability] = randf_range(HESITATION_MIN_DELAY_SEC, HESITATION_MAX_DELAY_SEC)

	# Jeśli jesteśmy w trakcie rzucania zdolności (channelling), odcinamy ruch i zwykłe strzały
	if is_casting_ability:
		blackboard.want_to_move = false
		if entity.movement_universal_script:
			entity.velocity = entity.movement_universal_script.movement_procedure(delta, entity.velocity, Vector2.ZERO)
		return

	if ability_casted_this_frame:
		return

	# 2. ZWYKŁY ATAK BRONIĄ LUB PIĘŚCIĄ (Z CACHE'OWANIEM WĘZŁÓW I INTERWAŁEM DOBORU BRONI)
	if not is_instance_valid(_ai_inventory):
		_ai_inventory = controller.get_node_or_null("AIInventoryController") as AIInventoryController
	if not is_instance_valid(_attack_component):
		_attack_component = entity.get_node_or_null("AttackComponent") as AttackComponent

	var switch_dist: float = DEFAULT_MELEE_SWITCH_DISTANCE_PX
	if controller.behavior_profile and "melee_switch_distance" in controller.behavior_profile:
		switch_dist = controller.behavior_profile.melee_switch_distance

	if _ai_inventory and not _ai_inventory.items.is_empty():
		_weapon_eval_timer -= delta
		if _weapon_eval_timer <= 0.0 or _last_weapon_index == -1:
			_weapon_eval_timer = WEAPON_EVAL_INTERVAL_SEC
			_select_best_weapon(_ai_inventory, edge_dist, switch_dist)

	var weapon: ItemInstance = _ai_inventory.get_current_item() if _ai_inventory else null

	if weapon != null:
		if edge_dist <= stats.get_total_range() and stats.can_attack():
			var has_los: bool = controller.perception.can_see_target(blackboard.target)
			if _attack_component and has_los:
				_attack_component.execute_attack(entity, blackboard.target, weapon, _ai_inventory, stats, has_los)
	else:
		if edge_dist <= stats.get_total_range() and stats.can_attack():
			stats.execute_attack_on_target(entity, blackboard.target)

func _process_ability_cooldowns(delta: float) -> void:
	for ability in _ability_cooldowns.keys():
		if _ability_cooldowns[ability] > 0.0:
			_ability_cooldowns[ability] -= delta

## Wybiera najlepszą broń w plecaku AI na podstawie polimorficznego kontraktu ItemComponent (SOLID - OCP).
func _select_best_weapon(inventory: AIInventoryController, distance: float, switch_dist: float) -> void:
	var best_index: int = -1
	var profile: Resource = controller.behavior_profile

	for i in range(inventory.items.size()):
		var item: ItemInstance = inventory.items[i]
		if item == null or item.data == null or item.data.components == null:
			continue
		if not item.state.get("is_usable_by_ai", true):
			continue

		for comp in item.data.components:
			if comp != null and comp.is_suitable_for_ai(profile, distance, switch_dist):
				best_index = i
				break
		if best_index != -1:
			break

	if best_index != -1 and best_index != _last_weapon_index:
		_last_weapon_index = best_index
		inventory.current_item_index = best_index

		# Odświeżenie atrybutów nowej broni na statystykach postaci
		var new_weapon: ItemInstance = inventory.get_current_item()
		var stats: InteractionAndAttackStatsComponent = controller.entity.interaction_and_attack_stats_script
		if new_weapon and new_weapon.data and new_weapon.data.components and stats != null:
			for new_comp in new_weapon.data.components:
				if new_comp != null and new_comp.apply_held_stats_to(stats):
					break
