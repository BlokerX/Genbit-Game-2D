class_name EffectProtectionRule
extends Resource
## Pojedyncza reguła ochronna określająca sposób blokowania, skracania, osłabiania
## lub natychmiastowego oczyszczania przychodzących i aktywnych efektów.
## Zgodna z zasadami SOLID (OCP / LSP) i Clean Code: wykorzystuje polimorficzne dopasowanie
## po skrypcie klasy efektu (.gd), kategorii żywiołu/domeny lub tagu (bez podatnych na błędy magicznych stringów).

const DEFAULT_MULTIPLIER: float = 1.0
const PERCENT_MULTIPLIER: float = 100.0

@export_group("Cel Ochrony (Filtr - SOLID OCP)")
## Przeciągnij tutaj skrypt konkretnego efektu (.gd), np. speed_effect.gd, poison_debuff_effect.gd, armor_buff_effect.gd.
## Reguła automatycznie rozpozna ten efekt oraz wszystkie klasy po nim dziedziczące bez edytowania klasy bazowej Effect.
@export var target_effect_script: Script = null
## Szeroka kategoria domenowa/żywiołowa efektu (np. POISON_ACID, FROST_FREEZE, STUN). Ustaw NONE, jeśli filtrujesz tylko po skrypcie .gd lub tagu.
@export var target_category: Effect.EffectCategory = Effect.EffectCategory.NONE
## Opcjonalny tag efektu (np. &"acid", &"curse"). Działa na każdy efekt posiadający ten tag w tablicy effect_tags.
@export var target_effect_tag: StringName = &""
## Jeśli włączone, reguła obejmuje wszystkie ofensywne/negatywne efekty (niezależnie od wybranej kategorii).
@export var apply_to_all_offensive_effects: bool = false

@export_group("Modyfikacja Przychodzących Efektów")
## Jeśli włączone, każdy nowy efekt pasujący do reguły zostanie w 100% zablokowany przed nałożeniem.
@export var block_completely: bool = false
## Szansa (0.0 - 1.0) na całkowite zignorowanie nowego efektu przy trafieniu (np. 0.5 = 50% szansy na uniknięcie efektu).
@export_range(0.0, 1.0, 0.01) var block_chance: float = 0.0
## Mnożnik czasu trwania nowego efektu (np. 0.4 skraca czas ogłuszenia/zamrożenia/trucizny o 60%).
@export_range(0.0, 2.0, 0.05) var duration_multiplier: float = DEFAULT_MULTIPLIER
## Mnożnik siły nowego efektu (np. 0.5 zmniejsza o połowę obrażenia, siłę odrzutu lub spowolnienie).
@export_range(0.0, 2.0, 0.05) var potency_multiplier: float = DEFAULT_MULTIPLIER

@export_group("Działanie na Bieżące (Już Aktywne) Efekty")
## Jeśli włączone (true), założenie lub aktywowanie przedmiotu NATYCHMIAST usuwa z postaci trwające już efekty pasujące do tej reguły.
## Jeśli wyłączone (false), trwające już na postaci efekty dokończą swój czas, a ochrona zadziała tylko na nowe efekty.
@export var clear_existing_active_effects: bool = false

@export_group("Opis Własny (Opcjonalne)")
## Opcjonalny własny tekst wyświetlany w Tooltipie zamiast opisu generowanego automatycznie.
@export var custom_rule_description: String = ""

## Sprawdza polimorficznie, czy podany zasób efektu pasuje do kryteriów tej reguły ochronnej (OCP / LSP).
func matches_effect(effect: Effect) -> bool:
	if effect == null:
		return false

	var has_any_filter: bool = false

	# 1. Filtr polimorficzny po skrypcie klasy (.gd) i hierarchii dziedziczenia
	if target_effect_script != null:
		has_any_filter = true
		if not _does_effect_match_script(effect, target_effect_script):
			return false

	# 2. Filtr po otwartym systemie tagów (effect_tags)
	if target_effect_tag != &"":
		has_any_filter = true
		if not effect.has_effect_tag(target_effect_tag):
			return false

	# 3. Filtr po wszystkich efektach ofensywnych
	if apply_to_all_offensive_effects:
		has_any_filter = true
		if not effect.is_offensive():
			return false

	# 4. Filtr po kategorii domenowej
	if target_category != Effect.EffectCategory.NONE:
		has_any_filter = true
		if not effect.matches_category(target_category):
			return false

	return has_any_filter

## Sprawdza, czy skrypt efektu (lub którykolwiek z jego skryptów bazowych) jest zgodny z target_effect_script.
func _does_effect_match_script(effect: Effect, expected_script: Script) -> bool:
	var current_script: Script = effect.get_script() as Script
	while current_script != null:
		if current_script == expected_script:
			return true
		current_script = current_script.get_base_script()
	return false

## Sprawdza, czy aktywny już na postaci efekt powinien zostać natychmiast usunięty po aktywacji tej reguły.
func should_purge_existing_effect(effect: Effect) -> bool:
	if not clear_existing_active_effects:
		return false
	return matches_effect(effect)

## Generuje czytelny opis reguły dla dymku Tooltipa oraz panelu informacji HUD (DRY).
func format_rule_description() -> String:
	if custom_rule_description != "":
		return custom_rule_description

	var target_label: String = _get_target_display_name()
	var parts: Array[String] = []

	if block_completely or block_chance >= 1.0:
		parts.append("Całkowita odporność")
	elif block_chance > 0.0:
		parts.append("%d%% szansy na blokadę" % int(round(block_chance * PERCENT_MULTIPLIER)))

	if not is_equal_approx(duration_multiplier, DEFAULT_MULTIPLIER):
		var diff_pct: int = int(round((DEFAULT_MULTIPLIER - duration_multiplier) * PERCENT_MULTIPLIER))
		if diff_pct > 0:
			parts.append("-%d%% czasu trwania" % diff_pct)
		else:
			parts.append("+%d%% czasu trwania" % abs(diff_pct))

	if not is_equal_approx(potency_multiplier, DEFAULT_MULTIPLIER):
		var potency_pct: int = int(round((DEFAULT_MULTIPLIER - potency_multiplier) * PERCENT_MULTIPLIER))
		if potency_pct > 0:
			parts.append("-%d%% siły efektu" % potency_pct)
		else:
			parts.append("+%d%% siły efektu" % abs(potency_pct))

	if clear_existing_active_effects:
		parts.append("usuwa aktywny efekt")

	if parts.is_empty():
		return ""
	return target_label + ": " + ", ".join(parts)

## Zwraca czytelną nazwę docelowego efektu na podstawie skryptu klasy, tagu lub kategorii domenowej.
func _get_target_display_name() -> String:
	if target_effect_script != null:
		var global_cls: StringName = target_effect_script.get_global_name()
		if global_cls != &"":
			return String(global_cls).trim_suffix("Effect")
		return target_effect_script.resource_path.get_file().get_basename().capitalize()
	if target_effect_tag != &"":
		return "Tag [" + String(target_effect_tag) + "]"
	if apply_to_all_offensive_effects:
		return "Negatywne efekty"
	return Effect.get_category_display_name(target_category)
