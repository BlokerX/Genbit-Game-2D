class_name ProtectiveItemComponent
extends ItemComponent
## Modularny komponent przedmiotu zapewniający ochronę przed kradzieżą, wybranymi akcjami
## oraz blokowanie, osłabianie lub natychmiastowe usuwanie aktywnych efektów (Stun, Freeze, Poison, Speed itp.).
## Realizuje zasady Single Responsibility (SRP) oraz Open/Closed (OCP).

## Określa wymagane miejsce przedmiotu w ekwipunku, aby jego ochrona była aktywna.
enum ActivationScope {
	WHEN_EQUIPPED,     ## Działa tylko wtedy, gdy przedmiot jest założony w slocie zbroi/akcesoriów.
	WHEN_HELD,         ## Działa wyłącznie wtedy, gdy gracz trzyma ten przedmiot aktywnie w dłoni.
	WHEN_IN_INVENTORY, ## Działa zawsze, dopóki przedmiot znajduje się w plecaku, dłoni lub na zbroi.
	EQUIPPED_OR_HELD   ## Działa zarówno po założeniu na slot zbroi, jak i podczas trzymania w dłoni.
}

const PERCENT_MULTIPLIER: float = 100.0
const FULL_RESISTANCE: float = 1.0

@export_category("Zakres Aktywacji Ochrony")
## Określa, gdzie musi znajdować się przedmiot, aby jego właściwości ochronne były aktywne.
@export var activation_scope: ActivationScope = ActivationScope.EQUIPPED_OR_HELD
## Jeśli włączone, mnożniki ochrony oraz redukcji kumulują się z liczbą sztuk przedmiotu w jednym stosie.
@export var scale_with_stack_amount: bool = false

@export_category("Ochrona przed Kradzieżą i Akcjami")
## Jeśli włączone, ten konkretny przedmiot jest przypięty na stałe i nigdy nie może zostać wytrącony ani skradziony z dłoni.
@export var cannot_be_stolen_itself: bool = false
## Dodatkowa odporność (0.0 - 1.0) chroniąca gracza przed kradzieżą jakiegokolwiek trzymanego przedmiotu (1.0 = 100% odporności).
@export_range(0.0, 1.0, 0.05) var steal_protection_bonus: float = 0.0
## Dodatkowe tagi akcji specjalnych (np. &"steal", &"disarm", &"trap"), przed którymi ten przedmiot całkowicie chroni.
@export var blocked_action_tags: Array[StringName] = []

@export_category("Reguły Modyfikacji i Czyszczenia Efektów")
## Lista reguł (EffectProtectionRule) określających, które efekty mają być blokowane, skracane, osłabiane lub usuwane.
@export var protection_rules: Array[EffectProtectionRule] = []

## Inicjalizuje flagę stanu przedmiotu chroniącą go przed kradzieżą.
func initialize_state(item_instance: ItemInstance) -> void:
	if item_instance != null and cannot_be_stolen_itself:
		item_instance.state["cannot_be_stolen"] = true

## Tworzy niezależną kopię komponentu oraz jego reguł ochronnych dla unikalnej instancji przedmiotu.
func create_unique_copy() -> ItemComponent:
	var copy: ProtectiveItemComponent = super.create_unique_copy() as ProtectiveItemComponent
	if copy != null:
		if blocked_action_tags != null:
			copy.blocked_action_tags = blocked_action_tags.duplicate()
		if protection_rules != null:
			var cloned_rules: Array[EffectProtectionRule] = []
			for rule in protection_rules:
				if rule != null:
					cloned_rules.append(rule.duplicate(true) as EffectProtectionRule)
			copy.protection_rules = cloned_rules
	return copy

## Sprawdza, czy komponent jest aktywny w bieżącym położeniu przedmiotu (zbroja / dłoń / plecak).
func is_active_in_context(is_equipped: bool, is_held: bool, is_in_inventory: bool) -> bool:
	match activation_scope:
		ActivationScope.WHEN_EQUIPPED:
			return is_equipped
		ActivationScope.WHEN_HELD:
			return is_held
		ActivationScope.WHEN_IN_INVENTORY:
			return is_in_inventory or is_held or is_equipped
		ActivationScope.EQUIPPED_OR_HELD:
			return is_equipped or is_held
	return false

# =========================================================================
# IMPLEMENTACJA POLIMORFICZNEGO KONTRAKTU OCHRONY (SOLID - OCP)
# =========================================================================

## Zwraca false, jeśli ten przedmiot ma włączoną ochronę przed wytrąceniem z dłoni.
func can_item_be_stolen(_item_instance: ItemInstance) -> bool:
	return not cannot_be_stolen_itself

## Zwraca wartość ochrony (0.0 - 1.0) przed określoną akcją (np. &"steal") w podanym kontekście ekwipunku.
func get_action_protection_score(
	item_instance: ItemInstance,
	action_tag: StringName,
	is_equipped: bool,
	is_held: bool,
	is_in_inventory: bool
) -> float:
	if not is_active_in_context(is_equipped, is_held, is_in_inventory):
		return 0.0

	if blocked_action_tags.has(action_tag):
		return FULL_RESISTANCE

	if action_tag == &"steal" and steal_protection_bonus > 0.0:
		var count: int = _get_effective_stack_count(item_instance)
		return clampf(steal_protection_bonus * float(count), 0.0, FULL_RESISTANCE)

	return 0.0

## Ocenia wpływ wszystkich reguł komponentu na nowo przychodzący efekt.
func evaluate_effect_protection(
	item_instance: ItemInstance,
	effect: Effect,
	is_equipped: bool,
	is_held: bool,
	is_in_inventory: bool
) -> Dictionary:
	var result: Dictionary = {
		"blocked": false,
		"duration_multiplier": 1.0,
		"potency_multiplier": 1.0,
		"modified": false
	}

	if effect == null or protection_rules.is_empty():
		return result
	if not is_active_in_context(is_equipped, is_held, is_in_inventory):
		return result

	var stack_count: int = _get_effective_stack_count(item_instance)

	for rule in protection_rules:
		if rule == null or not rule.matches_effect(effect):
			continue

		if rule.block_completely:
			result["blocked"] = true
			return result

		for _i in range(stack_count):
			if rule.block_chance > 0.0 and randf() <= rule.block_chance:
				result["blocked"] = true
				return result

			if not is_equal_approx(rule.duration_multiplier, 1.0):
				result["duration_multiplier"] = float(result["duration_multiplier"]) * rule.duration_multiplier
				result["modified"] = true

			if not is_equal_approx(rule.potency_multiplier, 1.0):
				result["potency_multiplier"] = float(result["potency_multiplier"]) * rule.potency_multiplier
				result["modified"] = true

	return result

## Sprawdza, czy którakolwiek reguła tego komponentu nakazuje natychmiastowe usunięcie już trwającego efektu.
func should_purge_active_effect(
	_item_instance: ItemInstance,
	active_effect: Effect,
	is_equipped: bool,
	is_held: bool,
	is_in_inventory: bool
) -> bool:
	if active_effect == null or protection_rules.is_empty():
		return false
	if not is_active_in_context(is_equipped, is_held, is_in_inventory):
		return false

	for rule in protection_rules:
		if rule != null and rule.should_purge_existing_effect(active_effect):
			return true

	return false

func _get_effective_stack_count(item_instance: ItemInstance) -> int:
	if not scale_with_stack_amount or item_instance == null:
		return 1
	return maxi(1, int(item_instance.state.get("amount", 1)))

func _get_scope_label() -> String:
	match activation_scope:
		ActivationScope.WHEN_EQUIPPED:
			return "Gdy założone"
		ActivationScope.WHEN_HELD:
			return "W dłoni"
		ActivationScope.WHEN_IN_INVENTORY:
			return "W plecaku"
		ActivationScope.EQUIPPED_OR_HELD:
			return "Założone / W dłoni"
	return ""

# =========================================================================
# OPISY DLA UI (Tooltip i Panel HUD - OCP)
# =========================================================================

## Formatuje informacje o ochronie do wyświetlenia w dymku (Tooltip) po najechaniu myszką na slot.
func get_tooltip_info(_item_instance: ItemInstance) -> String:
	var lines: Array[String] = _collect_protection_description_lines()
	if lines.is_empty():
		return ""
	var text: String = "Ochrona (" + _get_scope_label() + "):\n"
	for line in lines:
		text += "- " + line + "\n"
	return text

## Formatuje informacje o ochronie do wyświetlenia w prawym górnym panelu HUD.
func get_hud_info(_item_instance: ItemInstance, is_advanced: bool) -> String:
	var lines: Array[String] = _collect_protection_description_lines()
	if lines.is_empty():
		return ""
	var text: String = ""
	if is_advanced:
		text += "Właściwości Ochronne (" + _get_scope_label() + "):\n"
		for line in lines:
			text += "  - " + line + "\n"
	else:
		text += "Ochrona Specjalna: " + str(lines.size()) + "\n"
	return text

func _collect_protection_description_lines() -> Array[String]:
	var lines: Array[String] = []
	if cannot_be_stolen_itself:
		lines.append("Przedmiot niewytrącalny (Odporny na kradzież)")
	if steal_protection_bonus >= FULL_RESISTANCE:
		lines.append("Całkowita ochrona ekwipunku przed kradzieżą")
	elif steal_protection_bonus > 0.0:
		lines.append("Ochrona przed kradzieżą: +%d%%" % int(round(steal_protection_bonus * PERCENT_MULTIPLIER)))

	for tag in blocked_action_tags:
		if tag != &"" and tag != &"steal":
			lines.append("Blokuje akcję: " + String(tag))

	for rule in protection_rules:
		if rule != null:
			var desc: String = rule.format_rule_description()
			if desc != "":
				lines.append(desc)
	return lines
