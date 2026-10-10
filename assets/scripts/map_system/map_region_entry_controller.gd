class_name MapRegionEntryController
extends RefCounted

## Zarządza dołączeniem gracza do pokoju, pozycjonowaniem i efektami wejścia.
## Umieszcza gracza w pokoju i odtwarza efekty środowiskowe wejścia.
func place_player_in_region(
	player: PlayerCharacter,
	region: MapRegion,
	target_door: Node2D,
	force_teleport: bool,
	spawn_requested_callback: Callable
) -> void:
	if player == null or region == null:
		push_error("MapRegionEntryController wymaga gracza i docelowego pokoju.")
		return

	if not player.entity_spawn_requested.is_connected(spawn_requested_callback):
		player.entity_spawn_requested.connect(spawn_requested_callback)

	# Szukamy węzła Y-Sort i dodajemy gracza
	var target_parent = region.find_child("Entities")
	if not target_parent:
		target_parent = region
	target_parent.add_child(player)

	# CZYŚCIMY SCHOWEK - gracz wrócił bezpiecznie do drzewa!
	GlobalLevelManager.stored_player = null

	# --- ROZDZIELENIE LOGIKI: Zamiast grzebać w zmiennych gracza, prosimy go o reset ---
	# Ekran w tym momencie jest całkowicie czarny!
	if force_teleport and player.has_method("reset_state_for_respawn"):
		player.reset_state_for_respawn()
	# ----------------------------------------------------------------------------------

	# --- POPRAWIONE POZYCJONOWANIE (Zwrócony blok obsługujący RESPawn!) ---
	if target_door:
		if "spawn_point" in target_door and target_door.spawn_point != null:
			if target_door is Door and target_door.spawn_point.position.length() > 5.0:
				player.global_position = target_door.spawn_point.global_position
			elif target_door is Door:
				var inward_dir = -Vector2(target_door.get_direction_offset())
				var safe_push_distance = 64.0
				player.global_position = target_door.global_position + (inward_dir * safe_push_distance)
			else:
				player.global_position = target_door.spawn_point.global_position
		else:
			player.global_position = target_door.global_position
	else:
		# BRAK DRZWI: To jest Start Gry lub Respawn klawiszem R!
		if region.spawn_points.size() > 0:
			player.global_position = region.spawn_points[0].global_position
		else:
			player.global_position = region.global_position + (region.size_px / 2.0)
	# ------------------------------------------------------------------------

	# Nakładamy nowe efekty typu AURA (nieskończone)
	for effect in region.ambient_aura_effects:
		if effect != null:
			var infinite_effect = effect.duplicate()

			# --- NOWE PODEJŚCIE: Używamy nowej flagi nieskończoności ---
			if "is_infinite" in infinite_effect:
				infinite_effect.is_infinite = true

			_apply_entry_effect(player, infinite_effect, true)

	# Nakładamy efekty typu KLĄTWA (Zostają po wyjściu)
	for effect in region.sticky_entry_effects:
		if effect != null:
			var normal_effect = effect.duplicate()
			# Klątwy z pułapek normalnie nałożymy przez receive_effect,
			# aby gracz MÓGŁ wyleczyć je np. antidotum po wybiegnięciu z pokoju.
			_apply_entry_effect(player, normal_effect, false)

func _apply_entry_effect(player: Node, effect: Effect, is_environment_aura: bool) -> void:
	if player.has_method("receive_map_entry_effect"):
		player.call("receive_map_entry_effect", effect, is_environment_aura)
	elif is_environment_aura and player.has_method("receive_environment_effect"):
		player.call("receive_environment_effect", effect)
	elif player.has_method("receive_effect"):
		player.call("receive_effect", effect)
