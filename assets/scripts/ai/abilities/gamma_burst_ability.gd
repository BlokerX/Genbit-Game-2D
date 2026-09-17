extends AIAbility
class_name GammaBurstAbility

@export_category("Zdolność: Promieniowanie Gamma")

@export_group("Obrażenia i Zasięg")
@export var blast_radius: float = 250.0
@export var cast_time: float = 1.5
@export var radiation_damage: int = 25

@export_group("Wsparcie Sojuszników")
@export var heal_amount: int = 50

@export_group("Wizualizacje i Warstwy")
## Z-Index (warstwa rysowania) dla strefy zagrożenia. Domyślnie -15 (np. GameLayers.FLOOR_HAZARD).
@export var aoe_z_index: int = GameLayers.HAZARD
## Kolor plamy ostrzegawczej (TelegraphedAOE) - domyślnie radioaktywna zieleń
@export var aoe_danger_color: Color = Color(0.2, 0.9, 0.1, 0.5)

func _init() -> void:
	ability_name = "Promieniowanie Gamma"
	cooldown = 15.0
	min_range = 0.0
	max_range = 250.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker): return
	var combat_ctrl = attacker.get_node_or_null("AIController/AICombatController")
	if combat_ctrl: combat_ctrl.is_casting_ability = true

	# Narysuj strefę na samym Naukowcu (Wybuch wokół niego)
	var aoe = TelegraphedAOE.new()
	var dmg_eff = DamageEffect.new(radiation_damage)
	var poison = PoisonEffect.new()
	aoe.setup(attacker.global_position, blast_radius, cast_time, [dmg_eff, poison], attacker)
	
	# Wyłączamy friendly_fire dla strefy, żeby nie zabiła sojuszników
	aoe.friendly_fire = false 
	
	# Przypisanie warstwy i koloru
	aoe.z_index = aoe_z_index
	aoe.z_as_relative = false
	if "danger_color" in aoe:
		aoe.danger_color = aoe_danger_color
	
	# BEZPIECZNE SPAWNOWANIE STREFY
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", aoe, attacker.global_position)
	else:
		var parent_node = attacker.get_parent()
		if parent_node:
			parent_node.add_child(aoe)
			aoe.global_position = attacker.global_position
		else:
			attacker.get_tree().current_scene.add_child(aoe)
			aoe.global_position = attacker.global_position
	
	# Zamiast bicia kolegów, Naukowiec ich leczy i buffuje!
	var my_faction = attacker.get_node_or_null("FactionComponent")
	if my_faction:
		for ally in attacker.get_tree().get_nodes_in_group("Character"):
			if ally == attacker: continue
			
			# DODAJEMY KRAWĘDZIE ZAMIAST STAREGO WARUNKU
			var ally_rad = ally.combat_radius if "combat_radius" in ally else 20.0
			var edge_dist = max(0.0, attacker.global_position.distance_to(ally.global_position) - ally_rad)
			
			if edge_dist <= blast_radius:
				if my_faction.get_disposition_toward(ally) == FactionComponent.Disposition.FRIENDLY:
					if ally.has_method("receive_effect"):
						# BUFFOWANIE SOJUSZNIKÓW
						ally.receive_effect(FrenzyBuffEffect.new())
						ally.receive_effect(HealEffect.new(heal_amount))

	await attacker.get_tree().create_timer(cast_time).timeout

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false
