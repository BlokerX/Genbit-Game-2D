extends AIAbility
class_name GammaBurstAbility

@export var blast_radius: float = 250.0
@export var cast_time: float = 1.5
@export var radiation_damage: int = 25

func _init() -> void:
	ability_name = "Promieniowanie Gamma"
	cooldown = 15.0
	min_range = 0.0
	max_range = 250.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	var combat_ctrl = attacker.get_node_or_null("AIController/AICombatController")
	if combat_ctrl: combat_ctrl.is_casting_ability = true

	# Narysuj strefę na samym Naukowcu (Wybuch wokół niego)
	var aoe = TelegraphedAOE.new()
	var dmg_eff = DamageEffect.new(radiation_damage)
	var poison = PoisonEffect.new()
	aoe.setup(attacker.global_position, blast_radius, cast_time, [dmg_eff, poison], attacker)
	
	# Wyłączamy friendly_fire dla strefy, żeby nie zabiła sojuszników
	aoe.friendly_fire = false 
	attacker.get_tree().current_scene.add_child(aoe)
	
	# Zamiast bicia kolegów, Naukowiec ich leczy i buffuje!
	var my_faction = attacker.get_node_or_null("FactionComponent")
	if my_faction:
		for ally in attacker.get_tree().get_nodes_in_group("Character"):
			if ally == attacker: continue
			if attacker.global_position.distance_to(ally.global_position) <= blast_radius:
				if my_faction.get_disposition_toward(ally) == FactionComponent.Disposition.FRIENDLY:
					if ally.has_method("receive_effect"):
						# BUFFOWANIE SOJUSZNIKÓW
						ally.receive_effect(FrenzyBuffEffect.new())
						ally.receive_effect(HealEffect.new(50))

	await attacker.get_tree().create_timer(cast_time).timeout

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false
