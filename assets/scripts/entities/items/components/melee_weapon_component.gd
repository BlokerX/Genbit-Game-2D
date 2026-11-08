class_name MeleeWeaponComponent
extends ItemComponent
## Komponent broni białej (walka wręcz).

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")
const PERCENT_MULTIPLIER: float = 100.0
const DURABILITY_CONSUMPTION_PER_HIT: int = 1

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
	var stats = actor.get("interaction_and_attack_stats_script")
	if stats == null:
		return

	# 1. Wgrywamy statystyki tego komponentu do aktora
	stats.change_item_cooldown(use_cooldown)
	stats.actual_attack_data = attack_data
	stats.actual_extra_effects = effects

	# 2. Wykonujemy cios
	stats.execute_attack_on_target(actor, target)
	FeedbackDispatcherType.play_for_actor(use_feedback, actor, target)

	# 3. Zużywamy wytrzymałość broni
	_item_instance.consume_durability(DURABILITY_CONSUMPTION_PER_HIT)

	# 4. Prosimy ekwipunek o posprzątanie, jeśli broń właśnie pękła
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		if inv != null:
			inv.clean_dead_items()
			inv.inventory_updated.emit()

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
