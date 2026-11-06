extends TimedEffect
class_name HealthOverTimeModifierEffect

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

## Czy każdy pojedynczy tick leczenia ma wywoływać zielony błysk obwódki ekranu?
## Domyślnie false, aby pasywne spodnie leczące i regeneracja nie migały po oczach co sekundę.
@export var show_heal_screen_flash: bool = false

func _init(_duration: float = 10.0, _tick_interval: float = 2.0, _hp_per_tick: int = 5) -> void:
	effect_name = "Health Over Time"
	effect_color = Color.WHITE
	duration = _duration
	tick_interval = _tick_interval
	hp_per_tick = _hp_per_tick
	effect_category = EffectCategory.HEAL if _hp_per_tick >= 0 else EffectCategory.POISON_ACID

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
	if target.get("health_stats_script") != null:
		var stats = target.health_stats_script
		# Dodatkowa tarcza: jeśli cel uzyskał odporność w trakcie trwania efektu, ignorujemy tick
		if stats.has_method("is_immune_to") and stats.is_immune_to(self):
			return
		if hp_per_tick > 0:
			# Nie leczymy i nie migamy ekranem, jeśli cel ma już 100% HP!
			if stats.health < stats.max_health:
				var silent_tick := is_silent_or_passive() or not show_heal_screen_flash
				stats.heal(hp_per_tick, silent_tick)
				print(effect_name, " leczy o ", hp_per_tick, " HP.")
		elif hp_per_tick < 0:
			# 1.0 = 100% przebicia pancerza, idealne dla trucizny/kwasu
			stats.take_damage(abs(hp_per_tick), 1.0)
			print(effect_name, " zadaje ", abs(hp_per_tick), " obrażeń!")

func is_offensive() -> bool:
	return hp_per_tick < 0
