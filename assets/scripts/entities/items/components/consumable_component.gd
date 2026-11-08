class_name ConsumableComponent
extends ItemComponent
## Komponent przedmiotów jednorazowych / spożywczych (mikstury, apteczki, jedzenie).

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")
const CONSUMED_AMOUNT_PER_USE: int = 1

@export_group("Oprawa użycia")
## Oprawa wizualna i dźwiękowa tego konkretnego przedmiotu jednorazowego.
@export var use_feedback: FeedbackCue

@export_category("Konsumpcja")
@export var use_cooldown: float = 0.5
## Lista efektów, które zostaną nałożone po użyciu.
@export var effects: Array[Effect] = []

func has_offensive_effects() -> bool:
	for effect in effects:
		if effect != null and effect.is_offensive():
			return true
	return false

func execute(actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	var any_effect_applied: bool = false

	# Próbujemy nałożyć wszystkie efekty z tablicy
	if actor.has_method("receive_effect"):
		for effect in effects:
			if effect != null:
				# Ważne: Klonujemy efekt, żeby nie nadpisać oryginału w zasobie!
				if actor.receive_effect(effect.duplicate(true)):
					any_effect_applied = true

	# Jeśli chociaż jeden efekt zadziałał (np. gracz nie miał pełnego HP przy leczeniu)
	if any_effect_applied:
		print("Przedmiot skonsumowany! Nałożono efekty.")
		FeedbackDispatcherType.play_for_actor(use_feedback, actor, actor)

		# Odpalamy cooldown użycia
		var stats = actor.get("interaction_and_attack_stats_script")
		if stats:
			stats.change_item_cooldown(use_cooldown)
			stats.reset_cooldown()

		# Zjadamy 1 sztukę
		_item_instance.consume_amount(CONSUMED_AMOUNT_PER_USE)

		# Prosimy ekwipunek o posprzątanie pustych slotów
		if actor.has_method("get_inventory"):
			var inv = actor.get_inventory()
			if inv != null:
				inv.clean_dead_items()
				inv.inventory_updated.emit()

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	var text: String = "Efekty po użyciu: " + str(effects.size()) + "\n"
	for effect in effects:
		if effect != null:
			text += "- " + effect.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = ""
	if is_advanced:
		text += "Efekty Konsumpcji (" + str(effects.size()) + "):\n"
		text += "Szybkość Użycia: " + str(use_cooldown) + "s\n"
		for effect in effects:
			if effect != null:
				text += "  - " + effect.effect_name
				if effect is TimedEffect:
					text += " (" + str((effect as TimedEffect).duration) + "s)"
				text += "\n"
	else:
		text += "Posiada Efekty Specjalne: Tak\n"

	text += format_conditions_hud_info()
	return text
