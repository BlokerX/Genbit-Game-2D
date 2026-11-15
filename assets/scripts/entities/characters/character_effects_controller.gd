class_name CharacterEffectsController
extends RefCounted
## Centralizuje aplikowanie, filtrowanie i usuwanie efektów przypisanych do postaci (SOLID - SRP).
## Rozdziela warstwy efektów: pasywne z ekwipunku (passive_source), aury środowiskowe (is_environment_aura) oraz zwykłe efekty czasowe.

## Odrzuca zwykłe efekty, gdy postać nie żyje albo jest w trakcie respawnu.
func receive_effect(
	target: Node2D, effect: Effect, is_dead: bool, is_respawning: bool
) -> bool:
	if is_dead or is_respawning or effect == null:
		return false
	return apply_effect(target, effect)

## Nakłada aurę środowiskową pokoju, której nie usuwają zwykłe mikstury oczyszczające.
func receive_environment_effect(
	target: Node2D,
	effects_collector: Node,
	effect: Effect,
	is_dead: bool,
	is_respawning: bool
) -> bool:
	if is_dead or is_respawning or effect == null:
		return false
	return apply_environment_effect(target, effects_collector, effect)

## Obsługuje efekty wejściowe mapy także podczas animowanego respawnu.
func receive_map_entry_effect(
	target: Node2D,
	effects_collector: Node,
	effect: Effect,
	is_dead: bool,
	is_environment_aura: bool
) -> bool:
	if is_dead or effect == null:
		return false
	if is_environment_aura:
		return apply_environment_effect(target, effects_collector, effect)
	return apply_effect(target, effect)

## Główna bramka aplikowania efektu z weryfikacją auto-obrażeń, odporności statystyk oraz komponentów ochronnych ekwipunku.
func apply_effect(target: Node2D, effect: Effect) -> bool:
	if target == null or effect == null:
		return false

	# 1. Tarcza auto-obrażeń (chroni bossa/postać przed własnymi atakami obszarowymi i plamami)
	if effect.is_offensive() and not effect.allow_self_inflict:
		if is_instance_valid(effect.source_entity) and effect.source_entity == target:
			return false

	# 2. Tarcza odporności statystyk (weryfikacja kategorii i nazw efektów w LifeStatsComponent)
	var hp_stats: LifeStatsComponent = target.get("health_stats_script") as LifeStatsComponent
	if hp_stats != null and hp_stats.has_method("is_immune_to"):
		if hp_stats.is_immune_to(effect):
			print("Cel [", target.name, "] jest odporny na efekt: ", effect.effect_name)
			return false

	# 3. Modularny interceptor ochrony przedmiotów (ProtectiveItemComponent - DIP / OCP)
	var effective_effect: Effect = effect
	if not effect.has_meta("passive_source") and target.has_method("preprocess_incoming_effect"):
		effective_effect = target.call("preprocess_incoming_effect", effect) as Effect
		if effective_effect == null:
			return false

	var success: bool = effective_effect.apply_effect(target)
	if success:
		print("Entity character otrzymał efekt: ", effective_effect.effect_name)
	else:
		print("Nie udało się nałożyć efektu na entity character.")
	return success

## Nakłada nieskończoną aurę środowiskową pokoju, pilnując by nigdy nie nadpisać efektu pasywnego z ubrania/ekwipunku.
func apply_environment_effect(
	target: Node2D, effects_collector: Node, effect: Effect
) -> bool:
	if effects_collector == null or effect == null:
		return false

	effect.set_meta("is_environment_aura", true)
	if "is_infinite" in effect:
		effect.is_infinite = true

	var success: bool = apply_effect(target, effect)
	if success:
		for child in effects_collector.get_children():
			if child.is_queued_for_deletion():
				continue
			var child_res: Effect = child.get("effect_resource") as Effect
			if child_res == null or child_res.effect_name != effect.effect_name:
				continue
			# Nigdy nie oznaczamy efektu pochodzącego z ubrania/ekwipunku jako aury środowiskowej!
			if child_res.has_meta("passive_source"):
				continue
			if child.has_meta("is_environment_aura") or child_res.has_meta("is_environment_aura"):
				child.set_meta("is_environment_aura", true)
				child.is_infinite = true
				print("Otrzymano/Odświeżono NIEUSUWALNĄ aurę pokoju: ", effect.effect_name)
				break
	return success

## Usuwa zwykłe efekty czasowe (np. przez miksturę oczyszczającą), pozostawiając aury środowiskowe i pasywne efekty ekwipunku.
func clear_all_effects(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			if _is_environment_aura_node(active_effect):
				continue
			if _is_passive_equipment_node(active_effect):
				continue
			_terminate_active_effect_node(effects_collector, active_effect, false)
		print("Usunięto wszystkie zwykłe efekty z entity character (Aury i Pasywki pozostały na miejscu).")
		return
	print("Nie znaleziono kontenera efektów w entity character.")

## Wymusza czyszczenie wyłącznie aur środowiskowych przy przejściu pomiędzy całymi poziomami (zachowuje efekty z ubrań!).
func clear_all_environment_effects(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			if active_effect.is_queued_for_deletion():
				continue
			if _is_passive_equipment_node(active_effect):
				continue
			if _is_environment_aura_node(active_effect):
				_terminate_active_effect_node(effects_collector, active_effect, true)
		print("System: Wymuszono usunięcie aur środowiskowych podczas zmiany mapy.")

## Usuwa wskazany efekt po nazwie przy wyjściu z pokoju (MapRegion).
## Chroni pasywne efekty z założonego ubrania/ekwipunku przed przypadkowym skasowaniem!
func remove_effect_by_name(effects_collector: Node, effect_name: String) -> void:
	if effects_collector == null:
		return

	# Krok 1: W pierwszej kolejności szukamy i zdejmujemy aurę środowiskową pokoju o tej nazwie
	for active_effect in effects_collector.get_children():
		if active_effect.is_queued_for_deletion() or _is_passive_equipment_node(active_effect):
			continue
		var eff_res: Effect = active_effect.get("effect_resource") as Effect
		if eff_res != null and eff_res.effect_name == effect_name and _is_environment_aura_node(active_effect):
			_terminate_active_effect_node(effects_collector, active_effect, true)
			print("System Mapy: Bezpiecznie zdjęto aurę pokoju: ", effect_name)
			return

	# Krok 2: Fallback dla zwykłych efektów niebędących pasywkami z ekwipunku
	for active_effect in effects_collector.get_children():
		if active_effect.is_queued_for_deletion() or _is_passive_equipment_node(active_effect):
			continue
		var eff_res: Effect = active_effect.get("effect_resource") as Effect
		if eff_res != null and eff_res.effect_name == effect_name:
			_terminate_active_effect_node(effects_collector, active_effect, true)
			print("System Mapy: Bezpiecznie zdjęto efekt: ", effect_name)
			return

## Czyści wszystkie efekty postaci, łącznie z aurami i efektami ekwipunku (używane wyłącznie przy śmierci/respawnie).
func purge_absolutely_everything(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			_terminate_active_effect_node(effects_collector, active_effect, false)
		print("System: Całkowicie zresetowano stan gracza (usunięto aury i efekty).")

## Sprawdza, czy dany węzeł aktywnego efektu pochodzi z założonego ubrania, dłoni lub plecaka.
func _is_passive_equipment_node(active_effect: Node) -> bool:
	if active_effect == null:
		return false
	var eff_res: Resource = active_effect.get("effect_resource") as Resource
	return eff_res != null and eff_res.has_meta("passive_source")

## Sprawdza, czy dany węzeł aktywnego efektu jest aurą środowiskową pokoju.
func _is_environment_aura_node(active_effect: Node) -> bool:
	if active_effect == null:
		return false
	if active_effect.has_meta("is_environment_aura") and bool(active_effect.get_meta("is_environment_aura")):
		return true
	var eff_res: Resource = active_effect.get("effect_resource") as Resource
	return eff_res != null and eff_res.has_meta("is_environment_aura") and bool(eff_res.get_meta("is_environment_aura"))

## Bezpiecznie kończy działanie węzła efektu i opcjonalnie od razu wypina go z kontenera (DRY).
func _terminate_active_effect_node(effects_collector: Node, active_effect: Node, detach_immediately: bool) -> void:
	active_effect.set_process(false)
	if active_effect.has_method("end_effect"):
		active_effect.end_effect()
	else:
		active_effect.queue_free()
	if detach_immediately and active_effect.get_parent() == effects_collector:
		effects_collector.remove_child(active_effect)
