class_name ItemComponent
extends Resource
## Bazowa klasa dla wszystkich komponentów zachowań przedmiotów (Architektura Komponentowa / SOLID).

const DEFAULT_AI_THREAT_RATIO: float = 0.10

@export_group("Warunki (Conditions)")
## Lista warunków, które muszą zostać spełnione jednocześnie, aby komponent mógł zadziałać.
@export var conditions: Array[ItemCondition] = []

## Opcjonalna funkcja wywoływana przy tworzeniu nowej instancji przedmiotu (ItemInstance).
func initialize_state(_item_instance: ItemInstance) -> void:
	pass

## Tworzy płytką kopię komponentu z własną, niezależną instancją AttackData oraz tablicami efektów.
## Gwarantuje, że ulepszenie statystyk jednego miecza/karabinu nie zmieni statystyk innych przedmiotów,
## jednocześnie nie duplikując w RAM-ie ciężkich tekstur, dźwięków i scen pocisków!
func create_unique_copy() -> ItemComponent:
	var copy: ItemComponent = duplicate(false) as ItemComponent
	if conditions != null:
		copy.conditions = conditions.duplicate()
	if "attack_data" in copy and copy.get("attack_data") != null:
		copy.set("attack_data", copy.get("attack_data").duplicate(false))
	if "effects" in copy and copy.get("effects") is Array:
		copy.set("effects", copy.get("effects").duplicate())
	if "weapon_effects" in copy and copy.get("weapon_effects") is Array:
		copy.set("weapon_effects", copy.get("weapon_effects").duplicate())
	if "passive_buffs" in copy and copy.get("passive_buffs") is Array:
		copy.set("passive_buffs", copy.get("passive_buffs").duplicate())
	return copy

## Sprawdza, czy wszystkie warunki do wykonania akcji są spełnione.
func can_execute(actor: Node2D, item_instance: ItemInstance) -> bool:
	for condition in conditions:
		# ZABEZPIECZENIE: Ignorujemy puste pola w Inspektorze
		if condition != null:
			if not condition.check_condition(actor, item_instance):
				return false
	return true

## CZYSTA FASADA: Wrapper, który Gracz i AI wywołują bez martwienia się o ręczne sprawdzanie warunków.
func try_execute(actor: Node2D, target: Node2D, item_instance: ItemInstance) -> bool:
	if not can_execute(actor, item_instance):
		return false
	execute(actor, target, item_instance)
	return true

## Główna funkcja wykonawcza nadpisywana w konkretnych komponentach.
func execute(_actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	pass

# =========================================================================
# INTERFEJS BOJOWY I PERCEPCJI AI (Zasada Open/Closed - OCP)
# =========================================================================

## Zwraca true, jeśli ten komponent reprezentuje broń bojową (wręcz, dystansową lub miotaną).
func is_weapon_component() -> bool:
	return false

## Zwraca true, jeśli komponent może zostać wykonany przez AttackComponent (broń lub stawiany obiekt/mina).
func is_executable_attack_component() -> bool:
	return is_weapon_component()

## Zwraca true, jeśli wykonanie ataku tym komponentem wymaga weryfikacji zasięgu walki wręcz.
func requires_melee_range_check() -> bool:
	return false

## Zwraca zasób FeedbackCue przypisany do użycia tego komponentu (lub null, jeśli brak).
func get_use_feedback() -> FeedbackCue:
	if "use_feedback" in self:
		return get("use_feedback") as FeedbackCue
	return null

## Wgrywa statystyki trzymanego przedmiotu (attack_data, cooldown, efekty) do zasobu statystyk ataku postaci (Resource).
## Zwraca true, jeśli komponent zmodyfikował statystyki bojowe.
func apply_held_stats_to(_attack_stats: Resource) -> bool:
	return false

## Sprawdza, czy dany komponent przedmiotu pasuje do profilu zachowania AI na podanym dystansie do celu.
func is_suitable_for_ai(_profile: Resource, _distance: float, _switch_dist: float) -> bool:
	return false

## Zwraca znormalizowaną ocenę zagrożenia (0.0 - 1.0) dla systemu ThreatAssessmentComponent w AI.
func get_ai_threat_score() -> float:
	return DEFAULT_AI_THREAT_RATIO

# =========================================================================
# INTERFEJS OPISÓW DLA UI (Zasada Open/Closed - OCP oraz Information Expert)
# =========================================================================

## Zwraca linie opisu tego komponentu do wyświetlenia w dymku (Tooltip) po najechaniu na slot ekwipunku.
func get_tooltip_info(_item_instance: ItemInstance) -> String:
	return ""

## Zwraca linie opisu tego komponentu do wyświetlenia w panelu informacji o trzymanym przedmiocie (HUD).
## Parametr is_advanced określa, czy gracz włączył widok szczegółowy (InfoMode.ADVANCED).
func get_hud_info(_item_instance: ItemInstance, _is_advanced: bool) -> String:
	return ""

## Pomocnicza metoda formatująca listę wymagań (ItemCondition) przypisanych do tego komponentu.
func format_conditions_hud_info() -> String:
	if conditions == null or conditions.is_empty():
		return ""
	var text: String = ""
	var has_valid_condition: bool = false
	for cond in conditions:
		if cond != null:
			if not has_valid_condition:
				text += "Wymagania Użycia:\n"
				has_valid_condition = true
			text += "  - " + cond.get_condition_description() + "\n"
	return text
