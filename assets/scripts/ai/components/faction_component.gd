extends Node
class_name FactionComponent
## Komponent przynależności frakcyjnej zarządzający relacjami (wrogość, neutralność, sojusz) oraz pamięcią zemsty.

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
var active_grudges: Dictionary = {} # Pamięć urazów

## Uniwersalna metoda statyczna (SOLID - SRP/DIP): Sprawdza, czy dwa obiekty są po tej samej stronie (FRIENDLY).
## Parametry mają typ Variant, aby przekazanie referencji do usuniętego już strzelca (previously freed)
## nigdy nie powodowało błędu typu na wejściu funkcji przed sprawdzeniem is_instance_valid()!
static func is_ally_of(attacker: Variant, target: Variant, fallback_faction_name: StringName = &"") -> bool:
	if not is_instance_valid(target) or not (target is Node):
		return false

	var target_node: Node = target as Node
	var attacker_valid: bool = is_instance_valid(attacker) and (attacker is Node)

	# Każda postać jest sojusznikiem dla samej siebie (chroni przed samobójstwem od własnych plam i wybuchów)
	if attacker_valid and attacker == target_node:
		return true

	var target_faction: FactionComponent = target_node.get_node_or_null("FactionComponent") as FactionComponent
	if target_faction == null and "faction_component" in target_node:
		var raw_tf: Variant = target_node.get("faction_component")
		if is_instance_valid(raw_tf) and raw_tf is FactionComponent:
			target_faction = raw_tf as FactionComponent

	# Sytuacja A: Strzelec nadal żyje na mapie
	if attacker_valid:
		var attacker_node: Node = attacker as Node
		var attacker_faction: FactionComponent = attacker_node.get_node_or_null("FactionComponent") as FactionComponent
		if attacker_faction == null and "faction_component" in attacker_node:
			var raw_af: Variant = attacker_node.get("faction_component")
			if is_instance_valid(raw_af) and raw_af is FactionComponent:
				attacker_faction = raw_af as FactionComponent
		if attacker_faction != null:
			return attacker_faction.get_disposition_toward(target_node) == Disposition.FRIENDLY

	# Sytuacja B: Strzelec zniknął (zginął lub został zamrożony w chunku), sprawdzamy zapamiętaną nazwę frakcji
	if fallback_faction_name != &"" and target_faction != null:
		if target_faction.faction_name == fallback_faction_name and target_faction.friendly_to_same_faction:
			return true
		if target_faction.faction_relations.has(fallback_faction_name):
			return target_faction.faction_relations[fallback_faction_name] == Disposition.FRIENDLY
		if target_faction.faction_relations.has(String(fallback_faction_name)):
			return target_faction.faction_relations[String(fallback_faction_name)] == Disposition.FRIENDLY

	return false

func _physics_process(delta: float) -> void:
	if forgive_after_seconds <= 0.0 or active_grudges.is_empty():
		return

	# --- PAUZA ZAPOMINANIA (POŚCIG I POSZUKIWANIA) ---
	var parent_node: Node = get_parent()
	var ai_controller: Node = parent_node.get_node_or_null("AIController") if is_instance_valid(parent_node) else null
	if ai_controller and ai_controller.get("blackboard") != null:
		# Jeśli AI kogoś widzi (cel != null) LUB wciąż myszkuje w krzakach (has_last_known_position)
		if is_instance_valid(ai_controller.blackboard.target) or ai_controller.blackboard.has_last_known_position:
			# Utrzymujemy urazę "na świeżo". Odliczanie zacznie się od zera po powrocie do Idle!
			for key in active_grudges.keys():
				active_grudges[key] = forgive_after_seconds
			return # Przerywamy odliczanie
	# -------------------------------------------------

	var keys_to_remove: Array = []
	for key in active_grudges.keys():
		active_grudges[key] -= delta
		if active_grudges[key] <= 0.0:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		active_grudges.erase(key)
		# Bezpieczne czyszczenie obu słowników bez sprawdzania 'key is CharacterEntity' na potencjalnie usuniętym obiekcie
		personal_relations.erase(key)
		faction_relations.erase(key)
		if is_instance_valid(parent_node):
			print(parent_node.name + ": Zgubiłem trop. Wybaczam napastnikowi.")

func get_disposition_toward(other_character: Variant) -> Disposition:
	if not is_instance_valid(other_character) or not (other_character is Node):
		return Disposition.NEUTRAL

	var other_node: Node = other_character as Node
	# NAPRAWA KRYTYCZNA: Każda postać jest sojusznikiem dla samej siebie!
	# Chroni to bossa przed otrzymywaniem obrażeń od własnych plam kwasu i stref AoE.
	if other_node == get_parent():
		return Disposition.FRIENDLY

	if personal_relations.has(other_node):
		return personal_relations[other_node]

	var other_faction: FactionComponent = null
	if "faction_component" in other_node:
		var raw_of: Variant = other_node.get("faction_component")
		if is_instance_valid(raw_of) and raw_of is FactionComponent:
			other_faction = raw_of as FactionComponent
	if not other_faction:
		other_faction = other_node.get_node_or_null("FactionComponent") as FactionComponent

	if other_faction != null:
		var target_name: StringName = other_faction.faction_name

		if faction_relations.has(target_name):
			return faction_relations[target_name]
		elif faction_relations.has(String(target_name)):
			return faction_relations[String(target_name)]
		elif faction_relations.has(StringName(target_name)):
			return faction_relations[StringName(target_name)]

		if friendly_to_same_faction and target_name == self.faction_name:
			return Disposition.FRIENDLY

	return default_disposition

func set_personal_disposition(character: CharacterEntity, new_disposition: Disposition) -> void:
	if is_instance_valid(character):
		personal_relations[character] = new_disposition

func should_take_revenge(attacker: Variant) -> bool:
	if not is_instance_valid(attacker) or not (attacker is CharacterEntity) or attacker == get_parent():
		return false
	if revenge_mode == RevengeMode.NEVER_REVENGE:
		return false

	var attacker_entity: CharacterEntity = attacker as CharacterEntity
	var attacker_faction: FactionComponent = null
	if "faction_component" in attacker_entity:
		var raw_af: Variant = attacker_entity.get("faction_component")
		if is_instance_valid(raw_af) and raw_af is FactionComponent:
			attacker_faction = raw_af as FactionComponent
	if not attacker_faction:
		attacker_faction = attacker_entity.get_node_or_null("FactionComponent") as FactionComponent
	var attacker_faction_name: StringName = attacker_faction.faction_name if attacker_faction else &"Unknown"

	match revenge_mode:
		RevengeMode.REVENGE_ON_EVERYONE:
			return true
		RevengeMode.REVENGE_EXCEPT_FRIENDS:
			var current_disp: Disposition = get_disposition_toward(attacker_entity)
			if current_disp == Disposition.FRIENDLY:
				return false
			return true
		RevengeMode.REVENGE_ONLY_ON_SPECIFIC:
			if specific_revenge_factions.has(attacker_faction_name):
				return true
			return false

	return false

func process_revenge(attacker: Variant, is_shared: bool = false) -> void:
	if not should_take_revenge(attacker):
		return

	var attacker_entity: CharacterEntity = attacker as CharacterEntity
	var attacker_faction: FactionComponent = null
	if "faction_component" in attacker_entity:
		var raw_af: Variant = attacker_entity.get("faction_component")
		if is_instance_valid(raw_af) and raw_af is FactionComponent:
			attacker_faction = raw_af as FactionComponent
	if not attacker_faction:
		attacker_faction = attacker_entity.get_node_or_null("FactionComponent") as FactionComponent
	var target_faction_name: StringName = attacker_faction.faction_name if attacker_faction else &"Unknown"

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
		set_personal_disposition(attacker_entity, Disposition.HOSTILE)
		# Rejestrujemy osobistą urazę
		if forgive_after_seconds > 0.0:
			active_grudges[attacker_entity] = forgive_after_seconds

	if not is_shared and call_for_help_radius > 0.0:
		var my_owner: CharacterEntity = get_parent() as CharacterEntity
		if not is_instance_valid(my_owner):
			return

		var tree: SceneTree = get_tree()
		if not tree:
			return

		for char_node in tree.get_nodes_in_group("Character"):
			if not is_instance_valid(char_node) or char_node == my_owner or char_node == attacker_entity:
				continue

			if my_owner.global_position.distance_to(char_node.global_position) <= call_for_help_radius:
				var ally_faction: FactionComponent = null
				if "faction_component" in char_node:
					var raw_ally_fac: Variant = char_node.get("faction_component")
					if is_instance_valid(raw_ally_fac) and raw_ally_fac is FactionComponent:
						ally_faction = raw_ally_fac as FactionComponent
				if not ally_faction:
					ally_faction = char_node.get_node_or_null("FactionComponent") as FactionComponent

				var is_ally: bool = false
				if ally_faction:
					if ally_faction.faction_name == self.faction_name:
						is_ally = true
					elif ally_faction.get_disposition_toward(my_owner) == Disposition.FRIENDLY:
						is_ally = true

				if is_ally:
					ally_faction.process_revenge(attacker_entity, true)
