class_name PlayerHeldItemController
extends RefCounted
## Kontroler synchronizujący wygląd trzymanego w dłoni przedmiotu, aktywne źródło światła (z dłoni oraz slotów zbroi/akcesoriów)
## oraz statystyki bojowe gracza (SOLID - SRP / OCP).

var _held_item_visual: Sprite2D
var _player_light: PointLight2D
var _attack_stats: InteractionAndAttackStatsComponent

## Inicjalizuje kontroler referencjami do węzła graficznego dłoni, światła gracza oraz statystyk ataku.
func initialize(
	held_item_visual: Sprite2D,
	player_light: PointLight2D,
	attack_stats: InteractionAndAttackStatsComponent
) -> void:
	_held_item_visual = held_item_visual
	_player_light = player_light
	_attack_stats = attack_stats

## Odświeża wygląd przedmiotu w dłoni, statystyki bojowe oraz oświetlenie gracza (uwzględniając również sloty wyposażenia).
func refresh(item: ItemInstance, inventory: Inventory = null) -> void:
	_update_visual(item)
	_update_attack_stats(item)
	_update_light(item, inventory)

func _update_visual(item: ItemInstance) -> void:
	if item == null or item.data == null:
		_held_item_visual.texture = null
		_held_item_visual.hide()
		return

	_held_item_visual.texture = item.data.item_icon
	_held_item_visual.show()

## Polimorficznie wgrywa statystyki bojowe z komponentu broni (SOLID - OCP).
func _update_attack_stats(item: ItemInstance) -> void:
	_attack_stats.actual_extra_effects = []
	_attack_stats.actual_attack_data = _attack_stats.hand_attack_data

	var has_custom_cooldown: bool = false

	if item != null and item.data != null and item.data.components != null:
		for component in item.data.components:
			if component != null and component.apply_held_stats_to(_attack_stats):
				has_custom_cooldown = true
				break

	if not has_custom_cooldown:
		_attack_stats.change_item_cooldown(_attack_stats.hand_attack_cooldown)

## Aktualizuje PointLight2D gracza na podstawie najsilniejszego aktywnego LightSourceComponent (w dłoni lub w slocie Accessory/Zbroi).
func _update_light(item: ItemInstance, inventory: Inventory = null) -> void:
	var active_light: LightSourceComponent = null

	if inventory != null and inventory.has_method("get_active_light_source"):
		active_light = inventory.get_active_light_source()
	elif item != null and item.data != null and item.data.components != null:
		for component in item.data.components:
			if component is LightSourceComponent:
				var light_comp: LightSourceComponent = component as LightSourceComponent
				if light_comp.is_light_active_in_context(false, true, true):
					active_light = light_comp
					break

	if active_light != null:
		_player_light.enabled = true
		_player_light.energy = active_light.light_energy
		_player_light.texture_scale = active_light.light_scale
		_player_light.color = active_light.light_color
	else:
		_player_light.energy = 0.0
		_player_light.enabled = false
