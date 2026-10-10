class_name PlayerPassiveEffectController
extends RefCounted

var _character: CharacterEntity
var _effects_collector: Node

func initialize(character: CharacterEntity, effects_collector: Node) -> void:
	_character = character
	_effects_collector = effects_collector

func sync_held_passives(inventory: Inventory) -> void:
	_sync_passives(inventory.get_held_passives(), "HELD")

func sync_equipment_passives(inventory: Inventory) -> void:
	_sync_passives(inventory.get_equipment_passives(), "EQUIP")

func sync_inventory_passives(inventory: Inventory) -> void:
	_sync_passives(inventory.get_inventory_passives(), "INVENTORY")

func _sync_passives(effects: Array[Effect], source_name: String) -> void:
	_clear_passives_by_source(source_name)
	_apply_passives(effects, source_name)

func _clear_passives_by_source(source_name: String) -> void:
	if not is_instance_valid(_effects_collector):
		return

	for active_effect in _effects_collector.get_children():
		if active_effect.is_queued_for_deletion():
			continue
		var effect_resource = active_effect.get("effect_resource")
		if (
			effect_resource != null
			and effect_resource.has_meta("passive_source")
			and effect_resource.get_meta("passive_source") == source_name
		):
			active_effect.set_process(false)
			if active_effect.has_method("end_effect"):
				active_effect.end_effect()
			else:
				active_effect.queue_free()
			_effects_collector.remove_child(active_effect)

func _apply_passives(effects: Array[Effect], source_name: String) -> void:
	if not is_instance_valid(_character):
		return

	for effect in effects:
		if effect == null:
			continue

		var effect_copy: Effect = effect.duplicate(true)
		effect_copy.set_meta("passive_source", source_name)
		_character.receive_effect(effect_copy)
