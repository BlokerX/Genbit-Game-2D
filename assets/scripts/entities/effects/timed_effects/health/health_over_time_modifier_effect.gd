extends TimedEffect
class_name HealthOverTimeModifierEffect
## Efekt cyklicznego odnawiania zdrowia (Regeneracja) lub zadawania obrażeń w czasie (Trucizna / Kwas).

## Tryb zielonej obwódki ekranu gracza przy każdym tiku leczenia, gdy HP faktycznie wzrasta.
enum HealScreenFlashMode {
	NONE,   ## Brak podświetlenia ekranu przy tiku leczenia.
	SUBTLE, ## Delikatny, nierażący zielony impuls krawędzi ekranu przy każdym uleczeniu.
	FULL    ## Pełne, wyraźne zielone rozjaśnienie ekranu (jak przy apteczce).
}

## Przebicie pancerza stosowane przez obrażenia w czasie (1.0 = 100% penetracji dla trucizny/kwasu).
const DOT_ARMOR_PENETRATION: float = 1.0

@export_category("Modyfikatory Zdrowia w Czasie")
## Wartość na tick. Powyżej 0 = leczy. Poniżej 0 = zadaje obrażenia.
@export var hp_per_tick: int = 5:
	set(value):
		hp_per_tick = value
		# Automatyczna aktualizacja kategorii po wczytaniu właściwości z pliku .tres!
		if hp_per_tick < 0 and effect_category in [EffectCategory.NONE, EffectCategory.HEAL]:
			effect_category = EffectCategory.POISON_ACID
		elif hp_per_tick >= 0 and effect_category == EffectCategory.NONE:
			effect_category = EffectCategory.HEAL

@export_group("Oprawa Wizualna Regeneracji")
## Intensywność zielonej obwódki ekranu przy każdym tiku AKTYWNEJ regeneracji (np. mikstury).
## Domyślnie SUBTLE — delikatne podświetlenie krawędzi ekranu przy każdym faktycznym uleczeniu.
@export var active_heal_screen_flash_mode: HealScreenFlashMode = HealScreenFlashMode.SUBTLE
## Intensywność zielonej obwódki ekranu przy każdym tiku PASYWNEJ regeneracji (np. z założonego ekwipunku/przedmiotów).
## Domyślnie NONE — można przełączyć na SUBTLE lub FULL w Inspektorze dla konkretnego przedmiotu.
@export var passive_heal_screen_flash_mode: HealScreenFlashMode = HealScreenFlashMode.NONE
## Czy każdy tick aktywnej regeneracji (gdy HP faktycznie rośnie) ma wyświetlać zieloną poświatę i plusy na postaci?
@export var show_heal_character_vfx: bool = true
## Czy każdy tick pasywnej regeneracji z ekwipunku (gdy HP faktycznie rośnie) ma wyświetlać zieloną poświatę i plusy na postaci?
@export var show_passive_heal_character_vfx: bool = true

func _init(_duration: float = 10.0, _tick_interval: float = 2.0, _hp_per_tick: int = 5) -> void:
	effect_name = "Health Over Time"
	effect_color = Color.WHITE
	duration = _duration
	tick_interval = _tick_interval
	hp_per_tick = _hp_per_tick
	effect_category = EffectCategory.HEAL if _hp_per_tick >= 0 else EffectCategory.POISON_ACID

func apply_potency_multiplier(multiplier: float) -> void:
	var scaled_val: int = int(round(float(abs(hp_per_tick)) * maxf(0.0, multiplier)))
	if hp_per_tick < 0:
		hp_per_tick = -maxi(1, scaled_val)
	elif hp_per_tick > 0:
		hp_per_tick = maxi(1, scaled_val)

## Gwarantuje poprawną kategorię nawet dla starych plików .tres zapisanych przed dodaniem EffectCategory.
func get_effective_category() -> EffectCategory:
	if hp_per_tick < 0:
		if effect_category in [EffectCategory.NONE, EffectCategory.HEAL]:
			return EffectCategory.POISON_ACID
		return effect_category
	if effect_category == EffectCategory.NONE:
		return EffectCategory.HEAL
	return effect_category

func on_effect_tick(target: Node2D) -> void:
	if target.get("health_stats_script") == null:
		return

	var stats: LifeStatsComponent = target.health_stats_script as LifeStatsComponent
	if stats == null:
		return
	# Dodatkowa tarcza: jeśli cel uzyskał odporność w trakcie trwania efektu, ignorujemy tick
	if stats.has_method("is_immune_to") and stats.is_immune_to(self):
		return

	if hp_per_tick > 0:
		_apply_healing_tick(target, stats)
	elif hp_per_tick < 0:
		# 1.0 = 100% przebicia pancerza, idealne dla trucizny/kwasu
		stats.take_damage(abs(hp_per_tick), DOT_ARMOR_PENETRATION)
		print(effect_name, " zadaje ", abs(hp_per_tick), " obrażeń!")

## Wykonuje pojedynczy tick leczenia i uruchamia odpowiednio dobraną oprawę na postaci oraz ekranie (SRP).
func _apply_healing_tick(target: Node2D, stats: LifeStatsComponent) -> void:
	# Nie leczymy i nie uruchamiamy efektów wizualnych, jeśli cel ma już 100% HP!
	if stats.health >= stats.max_health:
		return

	# Wywołujemy heal z silent = true, aby dokładnie sterować trybem FULL vs SUBTLE bez podwójnego wyzwalania.
	var healed: int = stats.heal(hp_per_tick, true)
	if healed <= 0:
		return

	var is_passive: bool = has_meta("passive_source")
	var flash_mode: HealScreenFlashMode = _resolve_screen_flash_mode(is_passive)

	var show_char_vfx: bool = show_passive_heal_character_vfx if is_passive else show_heal_character_vfx
	if show_char_vfx and target.has_method("play_heal_reaction"):
		var is_subtle_char_vfx: bool = (flash_mode != HealScreenFlashMode.FULL)
		target.call("play_heal_reaction", is_subtle_char_vfx)

	if flash_mode != HealScreenFlashMode.NONE and target.has_method("play_heal_screen_feedback"):
		var is_subtle_screen: bool = (flash_mode == HealScreenFlashMode.SUBTLE)
		target.call("play_heal_screen_feedback", is_subtle_screen)

	print(effect_name, " leczy o ", healed, " HP.")

func _resolve_screen_flash_mode(is_passive: bool) -> HealScreenFlashMode:
	if not show_screen_feedback:
		return HealScreenFlashMode.NONE
	return passive_heal_screen_flash_mode if is_passive else active_heal_screen_flash_mode

func is_offensive() -> bool:
	return hp_per_tick < 0
