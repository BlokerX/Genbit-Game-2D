class_name PlayerHeldItemController
extends RefCounted

var _held_item_visual: Sprite2D
var _player_light: PointLight2D
var _attack_stats: InteractionAndAttackStatsComponent

func initialize(
	held_item_visual: Sprite2D,
	player_light: PointLight2D,
	attack_stats: InteractionAndAttackStatsComponent
) -> void:
	_held_item_visual = held_item_visual
	_player_light = player_light
	_attack_stats = attack_stats

func refresh(item: ItemInstance) -> void:
	_update_visual(item)
	_update_attack_stats(item)
	_update_light(item)

func _update_visual(item: ItemInstance) -> void:
	if item == null or item.data == null:
		_held_item_visual.texture = null
		_held_item_visual.hide()
		return

	_held_item_visual.texture = item.data.item_icon
	_held_item_visual.show()

func _update_attack_stats(item: ItemInstance) -> void:
	_attack_stats.actual_extra_effects = []
	_attack_stats.actual_attack_data = _attack_stats.hand_attack_data

	var has_custom_cooldown := false
	if item != null and item.data != null and item.data.components != null:
		for component in item.data.components:
			if component is MeleeWeaponComponent:
				_attack_stats.change_item_cooldown(component.use_cooldown)
				if component.attack_data != null:
					_attack_stats.actual_attack_data = component.attack_data
				_attack_stats.actual_extra_effects = component.effects
				has_custom_cooldown = true
				break
			elif component is RangedWeaponComponent:
				_attack_stats.change_item_cooldown(component.use_cooldown)
				if component.attack_data != null:
					_attack_stats.actual_attack_data = component.attack_data
				_attack_stats.actual_extra_effects = component.weapon_effects
				has_custom_cooldown = true
				break

	if not has_custom_cooldown:
		_attack_stats.change_item_cooldown(_attack_stats.hand_attack_cooldown)

func _update_light(item: ItemInstance) -> void:
	var light_applied := false
	if item != null and item.data != null and item.data.components != null:
		for component in item.data.components:
			if component is LightSourceComponent:
				_player_light.enabled = true
				_player_light.energy = component.light_energy
				_player_light.texture_scale = component.light_scale
				_player_light.color = component.light_color
				light_applied = true
				break

	if not light_applied:
		_player_light.energy = 0.0
		_player_light.enabled = false
