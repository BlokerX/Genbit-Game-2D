@abstract
extends Effect
class_name TimedEffect
## Abstrakcyjna klasa bazowa dla wszystkich efektów czasowych, pasywnych oraz aur środowiskowych.

## Krok zaokrąglania modyfikatorów zmiennoprzecinkowych.
## Zapobiega błędom precyzji procesora (float drift, np. 0.99999994 zamiast 1.0) po zdjęciu buffa.
const STAT_MODIFIER_SNAP_STEP: float = 0.0001
const MIN_TIMED_EFFECT_DURATION_SEC: float = 0.05

@export_group("Czas Trwania i Tiki")
## Czas trwania efektu w sekundach (ignorowany, gdy is_infinite == true).
@export var duration : float = 5.0
## Czy efekt ma trwać w nieskończoność (np. dopóki gracz nosi pancerz lub przebywa w aurze pokoju)?
@export var is_infinite : bool = false 
## Odstęp (w sekundach) między kolejnymi wywołaniami on_effect_tick(). Wartość 0.0 wyłącza tiki.
@export var tick_interval : float = 1.0

@export_group("Zasady Sumowania (Stacking)")
## Jeśli włączone (true - domyślnie dla modyfikatorów statystyk), założenie kilku przedmiotów dających ten sam efekt
## (np. Spodnie +20 Armor i Buty +20 Armor) zsumuje ich wartości (+40 Armor).
## Jeśli wyłączone (false - dla efektów stanu całkowitego jak Nieśmiertelność, Duch, Niewidzialność), efekt nie będzie się sumował.
@export var stack_passive_instances : bool = true
## Jeśli włączone (true), wielokrotne nałożenie aktywnego efektu (np. wypicie dwóch mikstur) zsumuje ich działanie zamiast tylko odświeżać czas trwania.
@export var stack_active_applications : bool = false

func apply_duration_multiplier(multiplier: float) -> void:
	if not is_infinite:
		duration = maxf(MIN_TIMED_EFFECT_DURATION_SEC, duration * maxf(0.0, multiplier))

func can_stack_passive_instances() -> bool:
	return stack_passive_instances

func apply_effect(target : Node2D) -> bool:
	var effect_parent : Node = target
	if "effects_collector" in target and target.effects_collector != null:
		effect_parent = target.effects_collector

	var my_is_aura: bool = self.has_meta("is_environment_aura") and self.get_meta("is_environment_aura") == true
	var my_passive_src: String = str(self.get_meta("passive_source")) if self.has_meta("passive_source") else ""
	var my_passive_id: String = str(self.get_meta("passive_instance_id")) if self.has_meta("passive_instance_id") else ""

	# 1. SPRAWDZAMY, CZY EFEKT POWINIEN ODŚWIEŻYĆ ISTNIEJĄCĄ INSTANCJĘ, CZY DODAĆ KOLEJNĄ (SUMOWANIE)
	for child in effect_parent.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.get("effect_resource") != null and child.effect_resource.effect_name == self.effect_name:
			var child_res: Effect = child.effect_resource
			var child_is_aura: bool = child_res.has_meta("is_environment_aura") and child_res.get_meta("is_environment_aura") == true
			var child_passive_src: String = str(child_res.get_meta("passive_source")) if child_res.has_meta("passive_source") else ""
			var child_passive_id: String = str(child_res.get_meta("passive_instance_id")) if child_res.has_meta("passive_instance_id") else ""

			if my_is_aura != child_is_aura:
				continue

			var should_merge_into_existing: bool = false

			# Przypadek A: Efekt pasywny z ekwipunku / zbroi / dłoni
			if my_passive_src != "" or child_passive_src != "":
				if not can_stack_passive_instances():
					# Efekty całkowite (np. Immortality, Ghost, Invisibility) NIGDY się nie sumują - łączymy w 1 stan!
					if my_passive_src == child_passive_src:
						should_merge_into_existing = true
				else:
					# Efekty sumujące się (np. +20 Armor ze spodni i +20 Armor z butów) łączą się tylko wtedy,
					# gdy pochodzą z dokładnie tego samego wpisu (my_passive_id == child_passive_id)!
					if my_passive_src == child_passive_src and my_passive_id != "" and my_passive_id == child_passive_id:
						should_merge_into_existing = true
			# Przypadek B: Zwykły efekt aktywny (np. z mikstury, aury lub ataku wroga)
			else:
				if not stack_active_applications:
					should_merge_into_existing = true

			if should_merge_into_existing:
				set_meta("was_refreshed", true)
				if is_instance_valid(self.source_entity):
					child_res.source_entity = self.source_entity
					child_res.source_position = self.source_position

				if child.is_infinite and not self.is_infinite:
					return true
				if self.is_infinite:
					child.is_infinite = true

				child.duration = maxf(child.duration, self.duration)
				return true

	if has_meta("was_refreshed"):
		remove_meta("was_refreshed")

	# 2. TWORZYMY NOWY WĘZEŁ AKTYWNEGO EFEKTU
	var active_node: Node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/base/_active_effect.gd"))
	active_node.name = effect_name.replace(" ", "_")

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

func on_effect_start(_target : Node2D) -> void:
	pass

func on_effect_tick(_target : Node2D) -> void:
	pass

func on_effect_end(_target : Node2D) -> void:
	pass
