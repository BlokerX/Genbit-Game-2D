class_name EffectProtectionRule
extends Resource
## Pojedyncza reguła ochronna definiująca sposób blokowania lub osłabiania przychodzącego efektu.
## Wykorzystywana przez ProtectiveItemComponent do budowy modularnych odporności ekwipunku (SOLID - OCP).

const DEFAULT_MULTIPLIER: float = 1.0
const MIN_MULTIPLIER: float = 0.0
const MAX_MULTIPLIER: float = 5.0
const PERCENT_MULTIPLIER: float = 100.0

@export_group(" cel Ochrony (Filtr)")
## Kategoria efektu, na którą działa ta reguła (ustaw NONE, jeśli chcesz filtrować po nazwie lub wszystkich negatywnych).
@export var target_category: Effect.EffectCategory = Effect.EffectCategory.NONE
## Jeśli włączone, reguła obejmuje wszystkie ofensywne/negatywne efekty (niezależnie od ich kategorii).
@export var apply_to_all_offensive_effects: bool = false
## Opcjonalna dokładna nazwa efektu (np. "Freeze", "Stun", "Poison"). Jeśli puste, decyduje kategoria powyżej.
@export var target_effect_name: StringName = &""

@export_group("Modyfikacja i Blokada")
## Jeśli włączone, efekt pasujący do reguły zostanie w 100% zablokowany.
@export var block_completely: bool = false
## Szansa (0.0 - 1.0) na całkowite zignorowanie efektu przy trafieniu (np. 0.35 = 35% szansy na uniknięcie efektu).
@export_range(0.0, 1.0, 0.01) var block_chance: float = 0.0
## Mnożnik czasu trwania efektu (np. 0.4 skraca czas ogłuszenia/zamrożenia/trucizny o 60%).
@export_range(0.0, 2.0, 0.05) var duration_multiplier: float = DEFAULT_MULTIPLIER
## Mnożnik siły efektu (np. 0.5 zmniejsza o połowę obrażenia, siłę odrzutu lub spowolnienie).
@export_range(0.0, 2.0, 0.05) var potency_multiplier: float = DEFAULT_MULTIPLIER

## Sprawdza, czy podany efekt podlega tej regule ochronnej.
func matches_effect(effect: Effect) -> bool:
	if effect == null:
		return false

	if target_effect_name != &"":
		var incoming_name: String = effect.effect_name.to_lower().strip_edges()
		var expected_name: String = String(target_effect_name).to_lower().strip_edges()
		if incoming_name != expected_name:
			return false

	if apply_to_all_offensive_effects:
		return effect.is_offensive()

	if target_category != Effect.EffectCategory.NONE:
		return int(effect.get_effective_category()) == int(target_category)

	return target_effect_name != &""

## Generuje czytelny opis reguły dla dymku Tooltipa oraz panelu informacji HUD (DRY).
func format_rule_description() -> String:
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

	if parts.is_empty():
		return ""
	return target_label + ": " + ", ".join(parts)

func _get_target_display_name() -> String:
	if target_effect_name != &"":
		return String(target_effect_name)
	if apply_to_all_offensive_effects:
		return "Negatywne efekty"
	match target_category:
		Effect.EffectCategory.PHYSICAL_DAMAGE:
			return "Obrażenia fizyczne"
		Effect.EffectCategory.POISON_ACID:
			return "Trucizna i Kwas"
		Effect.EffectCategory.FIRE_BURN:
			return "Ogień i Podpalenie"
		Effect.EffectCategory.FROST_FREEZE:
			return "Mróz i Zamrożenie"
		Effect.EffectCategory.RADIATION:
			return "Promieniowanie"
		Effect.EffectCategory.MENTAL_PSYCHOSIS:
			return "Psychoza"
		Effect.EffectCategory.STUN:
			return "Ogłuszenie (Stun)"
		Effect.EffectCategory.KNOCKBACK:
			return "Odrzut (Knockback)"
		Effect.EffectCategory.SLOW:
			return "Spowolnienie"
		Effect.EffectCategory.STAT_DEBUFF:
			return "Osłabienia statystyk"
		Effect.EffectCategory.INSTA_KILL:
			return "Natychmiastowa śmierć"
	return "Efekt"
