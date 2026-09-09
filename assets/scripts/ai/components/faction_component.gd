extends Node
class_name FactionComponent

enum Disposition { HOSTILE, NEUTRAL, FRIENDLY }

@export_category("Frakcja")
@export var faction_name: StringName = &"Monsters"
@export var default_disposition: Disposition = Disposition.HOSTILE
@export var faction_relations: Dictionary = {}

var personal_relations: Dictionary = {}

func get_disposition_toward(other_character: CharacterEntity) -> Disposition:
	if other_character == null or other_character == get_parent():
		return Disposition.NEUTRAL
		
	if personal_relations.has(other_character):
		return personal_relations[other_character]
		
	# Bezpieczne pobranie frakcji
	var other_faction = other_character.get("faction_component") as FactionComponent
	if not other_faction:
		other_faction = other_character.get_node_or_null("FactionComponent")
		
	if other_faction != null:
		var target_name = other_faction.faction_name
		# Sprawdzamy klucze w każdym formacie, by zapobiec błędom z Inspektora Godota
		if faction_relations.has(target_name):
			return faction_relations[target_name]
		elif faction_relations.has(String(target_name)):
			return faction_relations[String(target_name)]
		elif faction_relations.has(StringName(target_name)):
			return faction_relations[StringName(target_name)]
			
	return default_disposition

func set_personal_disposition(character: CharacterEntity, new_disposition: Disposition) -> void:
	personal_relations[character] = new_disposition
