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

## Jeśli włączone, jednostka z automatu traktuje członków swojej własnej frakcji jako FRIENDLY (Sojuszników), bez konieczności wpisywania tego w słownik.
@export var friendly_to_same_faction: bool = true

@export var faction_relations: Dictionary = {}

@export_category("System Zemsty")
@export var revenge_mode: RevengeMode = RevengeMode.REVENGE_EXCEPT_FRIENDS
## Używane TYLKO przy 'REVENGE_ONLY_ON_SPECIFIC'.
@export var specific_revenge_factions: Array[StringName] = []

@export_group("Skala Agresji i Rój")
@export var revenge_target: RevengeTarget = RevengeTarget.INDIVIDUAL
## Promień (w pikselach), w którym pobliscy sojusznicy (ta sama frakcja lub Friendly) usłyszą "wołanie o pomoc" i dołączą do ataku.
@export var call_for_help_radius: float = 800.0

var personal_relations: Dictionary = {}

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
		
		# 1. Szukamy wymuszonych relacji w słowniku
		if faction_relations.has(target_name): return faction_relations[target_name]
		elif faction_relations.has(String(target_name)): return faction_relations[String(target_name)]
		elif faction_relations.has(StringName(target_name)): return faction_relations[StringName(target_name)]
		
		# 2. Sprawdzamy czy to nasza krew (ta sama frakcja)
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
			# Wybaczamy obrażenia sojusznikom (FRIENDLY)
			if current_disp == Disposition.FRIENDLY: return false
			return true
		RevengeMode.REVENGE_ONLY_ON_SPECIFIC:
			if specific_revenge_factions.has(attacker_faction_name): return true
			return false
	return false

## GŁÓWNA LOGIKA ROJU I ESKALACJI
func process_revenge(attacker: CharacterEntity, is_shared: bool = false) -> void:
	if not should_take_revenge(attacker):
		return
		
	var attacker_faction = attacker.get("faction_component") as FactionComponent
	if not attacker_faction:
		attacker_faction = attacker.get_node_or_null("FactionComponent")
		
	var target_faction_name = attacker_faction.faction_name if attacker_faction else &"Unknown"
	
	# 1. Kogo nienawidzimy po ataku?
	if revenge_target == RevengeTarget.ENTIRE_FACTION and target_faction_name != &"Unknown":
		faction_relations[target_faction_name] = Disposition.HOSTILE
		faction_relations[String(target_faction_name)] = Disposition.HOSTILE
		faction_relations[StringName(target_faction_name)] = Disposition.HOSTILE
	else:
		set_personal_disposition(attacker, Disposition.HOSTILE)
		
	# 2. Wołanie o pomoc pobliskich sojuszników (Tylko jeśli to my oberwaliśmy pierwsi)
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
					# Przekazujemy cel sojusznikowi. is_shared = true zapobiega nieskończonym łańcuchom krzyków.
					ally_faction.process_revenge(attacker, true)
