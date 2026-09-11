extends Node
class_name FactionComponent

enum Disposition { HOSTILE, NEUTRAL, FRIENDLY }

enum RevengeMode {
	REVENGE_ON_EVERYONE,      ## Mści się na absolutnie KAŻDYM, kto go uderzy (nawet na swoich).
	REVENGE_EXCEPT_FRIENDS,   ## Ignoruje przypadkowy ostrzał sojuszników. Mści się na Neutralnych i Wrogach.
	REVENGE_ONLY_ON_SPECIFIC, ## Mści się TYLKO na frakcjach wypisanych na liście.
	NEVER_REVENGE             ## Pacyfista. Nigdy nie reaguje na obrażenia.
}

enum RevengeTarget {
	INDIVIDUAL,      ## Mści się tylko na konkretnym osobniku, który zadał cios.
	ENTIRE_FACTION   ## Mści się na CAŁEJ rasie/frakcji napastnika (wszyscy stają się wrogami).
}

@export_category("Frakcja")
@export var faction_name: StringName = &"Monsters"
@export var default_disposition: Disposition = Disposition.HOSTILE

## Jeśli włączone, traktuje członków własnej frakcji jako FRIENDLY.
@export var friendly_to_same_faction: bool = true
@export var faction_relations: Dictionary = {}

@export_category("System Zemsty")
@export var revenge_mode: RevengeMode = RevengeMode.REVENGE_EXCEPT_FRIENDS
@export var specific_revenge_factions: Array[StringName] = []

@export_group("Skala Agresji i Rój")
@export var revenge_target: RevengeTarget = RevengeTarget.INDIVIDUAL
@export var call_for_help_radius: float = 800.0

@export_group("Wybaczanie")
## Czas (w sekundach), po którym frakcja zapomina o ataku. 0.0 oznacza wieczną urazę.
@export var forgive_after_seconds: float = 0.0

var personal_relations: Dictionary = {}
var active_grudges: Dictionary = {} # Pamięć uraz

func _physics_process(delta: float) -> void:
	if forgive_after_seconds <= 0.0 or active_grudges.is_empty():
		return
		
	# --- PAUZA ZAPOMINANIA (POŚCIG I POSZUKIWANIA) ---
	var ai_controller = get_parent().get_node_or_null("AIController")
	if ai_controller and ai_controller.blackboard:
		# Jeśli AI kogoś widzi (cel != null) LUB wciąż myszkuje w krzakach (has_last_known_position)
		if ai_controller.blackboard.target != null or ai_controller.blackboard.has_last_known_position:
			# Utrzymujemy urazę "na świeżo". Odliczanie zacznie się od zera po powrocie do Idle!
			for key in active_grudges.keys():
				active_grudges[key] = forgive_after_seconds
			return # Przerywamy odliczanie
	# -------------------------------------------------
		
	var keys_to_remove = []
	for key in active_grudges.keys():
		active_grudges[key] -= delta
		if active_grudges[key] <= 0.0:
			keys_to_remove.append(key)
			
	for key in keys_to_remove:
		active_grudges.erase(key)
		if key is CharacterEntity:
			personal_relations.erase(key)
		else:
			faction_relations.erase(key)
			
		print(get_parent().name + ": Zgubiłem trop. Wybaczam napastnikowi.")

func get_disposition_toward(other_character: CharacterEntity) -> Disposition:
	if other_character == null or other_character == get_parent():
		return Disposition.NEUTRAL
		
	if personal_relations.has(other_character):
		return personal_relations[other_character]
		
	var other_faction = other_character.get("faction_component") as FactionComponent
	if not other_faction:
		other_faction = other_character.get_node_or_null("FactionComponent")
		
	if other_faction != null:
		var target_name = other_faction.faction_name
		if faction_relations.has(target_name): return faction_relations[target_name]
		elif faction_relations.has(String(target_name)): return faction_relations[String(target_name)]
		elif faction_relations.has(StringName(target_name)): return faction_relations[StringName(target_name)]
		
		if friendly_to_same_faction and target_name == self.faction_name:
			return Disposition.FRIENDLY
			
	return default_disposition

func set_personal_disposition(character: CharacterEntity, new_disposition: Disposition) -> void:
	personal_relations[character] = new_disposition

func should_take_revenge(attacker: CharacterEntity) -> bool:
	if revenge_mode == RevengeMode.NEVER_REVENGE:
		return false
		
	var attacker_faction = attacker.get("faction_component") as FactionComponent
	if not attacker_faction:
		attacker_faction = attacker.get_node_or_null("FactionComponent")
		
	var attacker_faction_name = attacker_faction.faction_name if attacker_faction else &"Unknown"
	
	match revenge_mode:
		RevengeMode.REVENGE_ON_EVERYONE:
			return true
		RevengeMode.REVENGE_EXCEPT_FRIENDS:
			var current_disp = get_disposition_toward(attacker)
			if current_disp == Disposition.FRIENDLY: return false
			return true
		RevengeMode.REVENGE_ONLY_ON_SPECIFIC:
			if specific_revenge_factions.has(attacker_faction_name): return true
			return false
	return false

func process_revenge(attacker: CharacterEntity, is_shared: bool = false) -> void:
	if not should_take_revenge(attacker):
		return
		
	var attacker_faction = attacker.get("faction_component") as FactionComponent
	if not attacker_faction:
		attacker_faction = attacker.get_node_or_null("FactionComponent")
		
	var target_faction_name = attacker_faction.faction_name if attacker_faction else &"Unknown"
	
	if revenge_target == RevengeTarget.ENTIRE_FACTION and target_faction_name != &"Unknown":
		faction_relations[target_faction_name] = Disposition.HOSTILE
		faction_relations[String(target_faction_name)] = Disposition.HOSTILE
		faction_relations[StringName(target_faction_name)] = Disposition.HOSTILE
		
		# Rejestrujemy urazę na całej frakcji
		if forgive_after_seconds > 0.0:
			active_grudges[target_faction_name] = forgive_after_seconds
			active_grudges[String(target_faction_name)] = forgive_after_seconds
			active_grudges[StringName(target_faction_name)] = forgive_after_seconds
	else:
		set_personal_disposition(attacker, Disposition.HOSTILE)
		
		# Rejestrujemy osobistą urazę
		if forgive_after_seconds > 0.0:
			active_grudges[attacker] = forgive_after_seconds
		
	if not is_shared and call_for_help_radius > 0.0:
		var my_owner = get_parent() as CharacterEntity
		if not my_owner: return
		
		for char_node in get_tree().get_nodes_in_group("Character"):
			if char_node == my_owner or char_node == attacker: 
				continue
				
			if my_owner.global_position.distance_to(char_node.global_position) <= call_for_help_radius:
				var ally_faction = char_node.get("faction_component") as FactionComponent
				if not ally_faction:
					ally_faction = char_node.get_node_or_null("FactionComponent")
					
				var is_ally = false
				if ally_faction:
					if ally_faction.faction_name == self.faction_name:
						is_ally = true
					elif ally_faction.get_disposition_toward(my_owner) == Disposition.FRIENDLY:
						is_ally = true
						
				if is_ally:
					ally_faction.process_revenge(attacker, true)
