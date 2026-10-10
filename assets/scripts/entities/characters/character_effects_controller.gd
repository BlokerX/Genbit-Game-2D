class_name CharacterEffectsController
extends RefCounted

## Centralizuje aplikowanie i usuwanie efektów przypisanych do postaci.
## Postać nadal udostępnia dotychczasowe metody jako publiczne API.

## Odrzuca zwykłe efekty, gdy postać nie żyje albo jest w trakcie respawnu.
func receive_effect(
	target: Node2D,
	effect: Effect,
	is_dead: bool,
	is_respawning: bool
) -> bool:
	if is_dead or is_respawning:
		return false
	return apply_effect(target, effect)

## Nakłada aurę środowiskową, której nie usuwają zwykłe efekty oczyszczające.
func receive_environment_effect(
	target: Node2D,
	effects_collector: Node,
	effect: Effect,
	is_dead: bool,
	is_respawning: bool
) -> bool:
	if is_dead or is_respawning:
		return false
	return apply_environment_effect(target, effects_collector, effect)

## Obsługuje efekty mapy także podczas animowanego respawnu.
func receive_map_entry_effect(
	target: Node2D,
	effects_collector: Node,
	effect: Effect,
	is_dead: bool,
	is_environment_aura: bool
) -> bool:
	if is_dead:
		return false
	if is_environment_aura:
		return apply_environment_effect(target, effects_collector, effect)
	return apply_effect(target, effect)

func apply_effect(target: Node2D, effect: Effect) -> bool:
	var success := effect.apply_effect(target)
	if success:
		print("Entity character otrzymał efekt: ", effect.effect_name)
	else:
		print("Nie udało się nałożyć efektu na entity character.")
	return success

func apply_environment_effect(
	target: Node2D,
	effects_collector: Node,
	effect: Effect
) -> bool:
	if effects_collector == null:
		return false

	var success := effect.apply_effect(target)

	# Jeśli efekt został nałożony LUB odświeżony, szukamy go i twardo wbijamy właściwości aury
	if success:
		for child in effects_collector.get_children():
			if child.get("effect_resource") != null and child.effect_resource.effect_name == effect.effect_name:
				# Zabezpieczamy węzeł metadaną
				child.set_meta("is_environment_aura", true)
				# Wymuszamy nieskończoność bezpośrednio na zaktualizowanym węźle
				child.is_infinite = true

				print("Otrzymano/Odświeżono NIEUSUWONALNĄ aurę pokoju: ", effect.effect_name)
				break # Zrobione, przerywamy pętlę

	return success

## Usuwa zwykłe efekty, pozostawiając aury środowiskowe i pasywne efekty ekwipunku.
func clear_all_effects(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			# --- TARCZA OCHRONNA DLA AUR ---
			if active_effect.has_meta("is_environment_aura") and active_effect.get_meta("is_environment_aura") == true:
				continue

			# --- TARCZA OCHRONNA DLA EKWIPUNKU ---
			# Zapobiega wyczyszczeniu zbroi/ringów przez potkę oczyszczającą.
			if active_effect.get("effect_resource") != null and active_effect.effect_resource.has_meta("passive_source"):
				continue

			active_effect.set_process(false)
			if active_effect.has_method("end_effect"):
				active_effect.end_effect()
			else:
				active_effect.queue_free()
		print("Usunięto wszystkie zwykłe efekty z entity character (Aury i Pasywki pozostały na miejscu).")
		return
	print("Nie znaleziono kontenera efektów w entity character.")

## Wymusza czyszczenie aur przy przejściu pomiędzy całymi poziomami.
func clear_all_environment_effects(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			if active_effect.has_meta("is_environment_aura") and active_effect.get_meta("is_environment_aura") == true:
				active_effect.set_process(false)
				if active_effect.has_method("end_effect"):
					active_effect.end_effect()
				else:
					active_effect.queue_free()
		print("System: Wymuszono usunięcie aur środowiskowych podczas zmiany mapy.")

## Usuwa wskazany efekt, wykonując jego standardową logikę zakończenia.
func remove_effect_by_name(effects_collector: Node, effect_name: String) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			# Szukamy po nazwie zasobu (pomijając te usunięte w tej samej klatce)
			if active_effect.is_queued_for_deletion():
				continue

			if (
				active_effect.get("effect_resource") != null
				and active_effect.effect_resource.effect_name == effect_name
			):
				# Zatrzymujemy logikę
				active_effect.set_process(false)

				# Odpalamy akcję kończącą (np. przywrócenie normalnej prędkości)
				if active_effect.has_method("end_effect"):
					active_effect.end_effect()
				else:
					active_effect.queue_free()

				# NATYCHMIASTOWE wyrwanie z drzewa sceny, by UI od razu ukryło ikonę
				effects_collector.remove_child(active_effect)
				print("System Mapy: Bezpiecznie zdjęto efekt: ", effect_name)

## Czyści wszystkie efekty postaci, łącznie z aurami i efektami ekwipunku.
func purge_absolutely_everything(effects_collector: Node) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			active_effect.set_process(false)
			if active_effect.has_method("end_effect"):
				active_effect.end_effect()
			else:
				active_effect.queue_free()
		print("System: Całkowicie zresetowano stan gracza (usunięto aury i efekty).")
