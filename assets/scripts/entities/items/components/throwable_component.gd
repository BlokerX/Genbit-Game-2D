extends ItemComponent
class_name ThrowableComponent
## Komponent przedmiotów miotanych (noże do rzucania, granaty, bomby).

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")
const DEFAULT_THROW_SPAWN_OFFSET_PX: float = 35.0
const CONSUMED_AMOUNT_PER_THROW: int = 1

@export_group("Oprawa użycia")
## Oprawa wizualna i dźwiękowa tego konkretnego rzutu.
@export var use_feedback: FeedbackCue

@export_category("Ustawienia Rzutu")
@export var entity_scene: PackedScene
@export var throw_force: float = 400.0
@export var friction: float = 150.0 
@export var use_cooldown: float = 0.5
@export var effects: Array[Effect] = []

func execute(actor: Node2D, _target: Node2D, item_instance: ItemInstance) -> void:
	if entity_scene == null:
		push_error("ThrowableComponent: Brak przypisanej sceny!")
		return

	var stats = actor.get("interaction_and_attack_stats_script")
	if stats:
		stats.change_item_cooldown(use_cooldown)
		stats.reset_cooldown()

	var spawn_pos: Vector2 = actor.global_position
	var throw_dir: Vector2 = Vector2.DOWN

	if throw_force > 0.0 and actor.has_node("AimController"):
		var aim_ctrl = actor.get_node("AimController")
		var target_pos: Vector2 = aim_ctrl.aim_scanner.global_position
		if actor.get("is_using_mouse"):
			target_pos = actor.get_global_mouse_position()
		throw_dir = actor.global_position.direction_to(target_pos).normalized()
		var desired_spawn_pos: Vector2 = actor.global_position + (throw_dir * DEFAULT_THROW_SPAWN_OFFSET_PX)
		# Zabezpieczenie przed wrzuceniem granatu/noża bezpośrednio w ścianę przed graczem!
		spawn_pos = ItemPickup.calculate_safe_spawn_position(actor.global_position, desired_spawn_pos, actor)

	var entity = entity_scene.instantiate()

	if "shooter" in entity:
		entity.shooter = actor
	if "current_velocity" in entity:
		entity.current_velocity = throw_dir * throw_force
	if "friction" in entity:
		entity.friction = friction

	if "effects_to_apply" in entity:
		var cloned_effects: Array[Effect] = []
		for eff in effects:
			if eff != null:
				cloned_effects.append(eff.duplicate(true))
		entity.effects_to_apply = cloned_effects

	entity.global_position = spawn_pos
	if actor.has_signal("entity_spawn_requested"):
		actor.emit_signal("entity_spawn_requested", entity, spawn_pos)
	FeedbackDispatcherType.play_for_actor(use_feedback, actor, entity)

	# 4. Sprawdzenie nieskończonej amunicji i ewentualne zużycie
	var has_infinite_ammo: bool = false
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		if inv and "infinite_ammo" in inv and inv.infinite_ammo == true:
			has_infinite_ammo = true

	if not has_infinite_ammo:
		item_instance.consume_amount(CONSUMED_AMOUNT_PER_THROW)
		if actor.has_method("get_inventory"):
			var inv = actor.get_inventory()
			if inv:
				if inv.has_method("clean_dead_items"):
					inv.clean_dead_items()
				if inv.has_signal("inventory_updated"):
					inv.inventory_updated.emit()

func get_tooltip_info(_item_instance: ItemInstance) -> String:
	var text: String = "Przedmiot miotany (Siła: " + str(int(throw_force)) + ")\n"
	if not effects.is_empty():
		text += "Efekty trafienia: " + str(effects.size()) + "\n"
		for eff in effects:
			if eff != null:
				text += "- " + eff.effect_name + "\n"
	return text

func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = ""
	if is_advanced:
		text += "Siła Rzutu: " + str(throw_force) + "\n"
		text += "Szybkość Rzutu (Cooldown): " + str(use_cooldown) + "s\n"
		if not effects.is_empty():
			text += "Efekty Rzutu (" + str(effects.size()) + "):\n"
			for eff in effects:
				if eff != null:
					text += "  - " + eff.effect_name + "\n"
	else:
		text += "Broń Miotana\n"
	text += format_conditions_hud_info()
	return text
