class_name ConsumableComponent
extends ItemComponent

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")

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
	var any_effect_applied = false
	
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
			
		# Zjadamy 1 sztukę (Zlecamy to bezpośrednio instancji!)
		_item_instance.consume_amount(1)
		
		# Prosimy ekwipunek o posprzątanie pustych slotów
		if actor.has_method("get_inventory"):
			var inv = actor.get_inventory()
			inv.clean_dead_items()
			inv.inventory_updated.emit()
