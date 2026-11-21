extends AbilityComponent
class_name StealItemAbilityComponent
## Komponent zdolności AI odpowiadający za próbę wytrącenia/kradzieży trzymanego przedmiotu z dłoni trafionego celu (SOLID - SRP / OCP).
## Respektuje flagi ochronne przedmiotu (cannot_be_stolen / ProtectiveItemComponent) oraz odporność cc_resistance i &"steal" celu.
## Może zostać podpięty w pliku .tres do dowolnego archetypu zdolności (np. DashStrikeAbility, SpinSlashAbility, RadialWaveAbility).

const FULL_RESISTANCE_THRESHOLD: float = 1.0
const PERCENT_MULTIPLIER: float = 100.0

@export_group("Parametry Kradzieży / Wytrącenia")
## Bazowa szansa powodzenia wytrącenia przedmiotu po trafieniu (0.0 = 0%, 1.0 = 100%).
@export_range(0.0, 1.0, 0.01) var steal_success_chance: float = 0.35
## Czy odporność na kontrolę tłumu celu (cc_resistance) zmniejsza szansę na wytrącenie?
@export var affected_by_target_cc_resistance: bool = true
## Jeśli true, wytrąca cały stos trzymany w dłoni. Jeśli false, wytrąca tylko 1 sztukę przedmiotu.
@export var steal_entire_stack: bool = true
## Włącza szczegółowe logi przebiegu rzutu na szansę kradzieży w konsoli.
@export var debug_mode: bool = false

func on_target_hit(_ability: Resource, attacker: CharacterEntity, target: Node2D, _origin_pos: Vector2) -> void:
	if not is_instance_valid(target) or not (target is CharacterEntity):
		return
	var target_entity: CharacterEntity = target as CharacterEntity
	if target_entity.is_dead or target_entity.is_respawning:
		return
	_try_steal_held_item(attacker, target_entity)

## Wykonuje test prawdopodobieństwa i w razie powodzenia wytrąca przedmiot z aktywnego slotu celu.
func _try_steal_held_item(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not target.has_method("get_inventory"):
		return
	var inv: Variant = target.call("get_inventory")
	if not (inv is Inventory):
		return

	var inventory: Inventory = inv as Inventory
	var slot: SlotData = inventory.get_current_slot()
	if slot == null or slot.is_empty() or slot.item == null:
		return

	var effective_chance: float = _calculate_effective_steal_chance(target, slot.item)
	if effective_chance <= 0.0:
		if debug_mode:
			print("[StealItemComponent] Cel lub przedmiot jest całkowicie odporny na kradzież!")
		return

	var roll: float = randf()
	if roll <= effective_chance:
		var attacker_name: String = attacker.name if is_instance_valid(attacker) else "Przeciwnik"
		var stolen_item_name: String = slot.item.data.item_name if slot.item.data != null else "Nieznany Przedmiot"
		print(
			"%s wytrąca przedmiot graczowi! (%s | Szansa: %d%%)"
			% [attacker_name, stolen_item_name, int(round(effective_chance * PERCENT_MULTIPLIER))]
		)
		inventory.drop_current_item(steal_entire_stack)
	elif debug_mode:
		print("[StealItemComponent] Próba nieudana (Wylosowano: %.2f > Wymagane: %.2f)." % [roll, effective_chance])

## Oblicza finalną szansę powodzenia kradzieży z uwzględnieniem odporności postaci oraz komponentów ochronnych przedmiotu.
func _calculate_effective_steal_chance(target: CharacterEntity, item_instance: ItemInstance) -> float:
	if steal_success_chance <= 0.0 or item_instance == null or not is_instance_valid(target):
		return 0.0

	if item_instance.state.get("cannot_be_stolen", false) == true:
		return 0.0
	if item_instance.data != null and item_instance.data.components != null:
		for comp in item_instance.data.components:
			if comp != null and not comp.can_item_be_stolen(item_instance):
				return 0.0

	if target.has_method("is_action_blocked") and target.call("is_action_blocked", &"steal") == true:
		return 0.0

	var resistance: float = 0.0
	if affected_by_target_cc_resistance and target.health_stats_script != null:
		resistance = maxf(resistance, float(target.health_stats_script.cc_resistance))
	if target.has_method("get_action_resistance"):
		var action_res: float = float(target.call("get_action_resistance", &"steal"))
		resistance = clampf(1.0 - ((1.0 - resistance) * (1.0 - action_res)), 0.0, FULL_RESISTANCE_THRESHOLD)

	if resistance >= FULL_RESISTANCE_THRESHOLD:
		return 0.0

	return clampf(steal_success_chance * (1.0 - resistance), 0.0, 1.0)
