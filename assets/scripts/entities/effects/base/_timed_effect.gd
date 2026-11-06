@abstract
extends Effect
class_name TimedEffect

## Krok zaokrąglania modyfikatorów zmiennoprzecinkowych.
## Zapobiega błędom precyzji procesora (float drift, np. 0.99999994 zamiast 1.0) po zdjęciu buffa.
const STAT_MODIFIER_SNAP_STEP: float = 0.0001

@export var duration : float = 5.0
## Czy efekt ma trwać wiecznie?
@export var is_infinite : bool = false 
## Odstęp (w sekundach) między kolejnymi wykonaniami on_effect_tick(). Wartość 0.0 wyłącza tiki.
@export var tick_interval : float = 1.0

# Nadpisujemy metodę aplikowania z bazowego Effect
func apply_effect(target : Node2D) -> bool:
	var effect_parent : Node = target
	if "effects_collector" in target and target.effects_collector != null:
		effect_parent = target.effects_collector

	# Odczytujemy skąd pochodzi NASZ efekt
	var my_is_aura = self.has_meta("is_environment_aura") and self.get_meta("is_environment_aura") == true
	var my_passive_src = self.get_meta("passive_source") if self.has_meta("passive_source") else ""

	# 1. SPRAWDZAMY CZY EFEKT JUŻ ISTNIEJE NA CELU
	for child in effect_parent.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.get("effect_resource") != null and child.effect_resource.effect_name == self.effect_name:
			var child_res = child.effect_resource
			var child_is_aura = child_res.has_meta("is_environment_aura") and child_res.get_meta("is_environment_aura") == true
			var child_passive_src = child_res.get_meta("passive_source") if child_res.has_meta("passive_source") else ""

			# TARCZA KANAŁÓW: Nadpisujemy efekt TYLKO jeśli pochodzi z tego samego źródła!
			# Mróz z HELD (broń) vs Mróz z INVENTORY (Plecak) vs Mróz z potki ("" puste)
			if my_is_aura == child_is_aura and my_passive_src == child_passive_src:
				# Oznaczamy, że to tylko odświeżenie czasu trwania (zapobiega spamowi audio/VFX)
				set_meta("was_refreshed", true)

				# Aktualizujemy sprawcę na wypadek odświeżenia trucizny/kwasu
				if is_instance_valid(self.source_entity):
					child_res.source_entity = self.source_entity
					child_res.source_position = self.source_position

				if child.is_infinite and not self.is_infinite:
					return true
				if self.is_infinite:
					child.is_infinite = true
				child.duration = max(child.duration, self.duration)
				return true

	if has_meta("was_refreshed"):
		remove_meta("was_refreshed")

	# 2. JEŚLI NIE MA TAKIEGO EFEKTU W TYM KANALE, DODAJEMY NOWY
	var active_node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/base/_active_effect.gd"))
	active_node.name = effect_name.replace(" ", "_")

	# WAŻNE: Konfigurujemy dane PRZED dodaniem do drzewa, aby sygnał child_entered_tree w UI
	# od razu widział przypisany effect_resource bez konieczności czekania klatki!
	active_node.setup(target, self, duration, tick_interval, is_infinite)
	if my_is_aura:
		active_node.set_meta("is_environment_aura", true)

	effect_parent.add_child(active_node)
	print("Nałożono efekt czasowy: ", effect_name, " (Aura: ", my_is_aura, " | Equip: ", my_passive_src, ")")
	return true

## Bezpiecznie dodaje wartość do statystyki i zaokrągla wynik, eliminując błędy precyzji float.
static func snap_stat_addition(current_value: float, delta_value: float) -> float:
	return snappedf(current_value + delta_value, STAT_MODIFIER_SNAP_STEP)

## Bezpiecznie mnoży statystykę i zaokrągla wynik, eliminując błędy precyzji float.
static func snap_stat_multiplication(current_value: float, factor: float) -> float:
	return snappedf(current_value * factor, STAT_MODIFIER_SNAP_STEP)

## Bezpiecznie dzieli statystykę przy zdejmowaniu mnożnika i zaokrągla wynik.
static func snap_stat_division(current_value: float, divisor: float) -> float:
	if is_zero_approx(divisor):
		return current_value
	return snappedf(current_value / divisor, STAT_MODIFIER_SNAP_STEP)

# Metody do nadpisania w konkretnych efektach czasowych:
func on_effect_start(_target : Node2D) -> void:
	pass # Co ma się stać na samym początku?

func on_effect_tick(_target : Node2D) -> void:
	pass # Co ma się stać co każdy tick_interval?

func on_effect_end(_target : Node2D) -> void:
	pass # Co ma się stać po upływie czasu?
