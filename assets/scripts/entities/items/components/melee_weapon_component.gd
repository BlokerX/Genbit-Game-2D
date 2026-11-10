class_name MeleeWeaponComponent
extends ItemComponent
## Komponent broni białej (walka wręcz).

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")
const PERCENT_MULTIPLIER: float = 100.0
const DURABILITY_CONSUMPTION_PER_HIT: int = 1

# Stałe oceny zagrożenia dla AI w znormalizowanej skali 0.0 - 1.0 (zgodnej z ThreatAssessmentComponent)
const MELEE_BASE_AI_THREAT_RATIO: float = 0.30
const MELEE_EFFECT_AI_THREAT_BONUS: float = 0.05
const MAX_MELEE_AI_THREAT_RATIO: float = 0.65

@export_group("Oprawa użycia")
## Oprawa wizualna i dźwiękowa tego konkretnego ataku wręcz.
@export var use_feedback: FeedbackCue

@export var attack_data: AttackData
@export var use_cooldown: float = 1.0
@export var allow_auto_aim: bool = true
@export var effects: Array[Effect] = []

## Odpalamy, gdy gracz lub AI użyje tego przedmiotu na wrogu.
func execute(actor: Node2D, target: Node2D, _item_instance: ItemInstance) -> void:
	if target == null:
		return

	# Zabezpieczenie: Sprawdzamy czy aktor ma statystyki ataku
	var stats: Resource = actor.get("interaction_and_attack_stats_script") as Resource
	if stats == null:
		return

	# 1. Wgrywamy statystyki tego komponentu do aktora
	apply_held_stats_to(stats)

	# 2. Wykonujemy cios
	stats.call("execute_attack_on_target", actor, target)
	FeedbackDispatcherType.play_for_actor(use_feedback, actor, target)

	# 3. Zużywamy wytrzymałość broni
	_item_instance.consume_durability(DURABILITY_CONSUMPTION_PER_HIT)

	# 4. Prosimy ekwipunek o posprzątanie, jeśli broń właśnie pękła
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		if inv != null:
			inv.clean_dead_items()
			inv.inventory_updated.emit()

# --- IMPLEMENTACJA KONTRAKTU BOJOWEGO (SOLID - OCP) ---

func is_weapon_component() -> bool:
	return true

func requires_melee_range_check() -> bool:
	return true

func get_use_feedback() -> FeedbackCue:
	return use_feedback

func apply_held_stats_to(attack_stats: Resource) -> bool:
	if attack_stats == null:
		return false
	if attack_stats.has_method("change_item_cooldown"):
		attack_stats.call("change_item_cooldown", use_cooldown)
	if attack_data != null and "actual_attack_data" in attack_stats:
		attack_stats.set("actual_attack_data", attack_data)
	if "actual_extra_effects" in attack_stats:
		attack_stats.set("actual_extra_effects", effects)
	return true

func is_suitable_for_ai(profile: Resource, distance: float, switch_dist: float) -> bool:
	if profile == null or not bool(profile.get("can_use_melee_weapons")):
		return false
	return distance < switch_dist

## Zwraca poziom zagrożenia broni białej w skali 0.0 - 1.0 (poniżej progu 0.7 lufy broni palnej).
func get_ai_threat_score() -> float:
	var effects_bonus: float = float(effects.size()) * MELEE_EFFECT_AI_THREAT_BONUS if effects != null else 0.0
	return clampf(MELEE_BASE_AI_THREAT_RATIO + effects_bonus, 0.0, MAX_MELEE_AI_THREAT_RATIO)

# --- OPISY UI (OCP) ---

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	if attack_data == null:
		return ""
	var text: String = "Obrażenia: " + str(attack_data.damage) + "\n"
	if attack_data.critical_rate > 0.0:
		text += "Szansa na Kryta: " + str(attack_data.critical_rate * PERCENT_MULTIPLIER) + "%\n"
	if not effects.is_empty():
		for effect in effects:
			if effect != null:
				text += "- Efekt: " + effect.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = ""
	if attack_data != null:
		text += "Obrażenia: " + str(attack_data.damage) + "\n"
		if attack_data.critical_rate > 0.0:
			text += "Szansa na Kryta: " + str(attack_data.critical_rate * PERCENT_MULTIPLIER) + "%\n"
		if is_advanced:
			text += "Zasięg Ataku: " + str(attack_data.max_range) + "\n"
			text += "Szybkośc (Cooldown): " + str(use_cooldown) + "s\n"
			if attack_data.critical_damage > 0:
				text += "Moc Krytyka: +" + str(attack_data.critical_damage) + " DMG\n"
			if attack_data.stun_time > 0.0:
				text += "Ogłuszenie: " + str(attack_data.stun_time) + "s\n"
	if not effects.is_empty():
		if is_advanced:
			text += "Efekty Nakładane (" + str(effects.size()) + "):\n"
			for effect in effects:
				if effect != null:
					text += "  - " + effect.effect_name + "\n"
		else:
			text += "Statusy Specjalne: Tak\n"
	return text
