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

	_connect_spawn_request(player, spawn_requested_callback)
	_attach_player_to_region(player, region)

	# CZYŚCIMY SCHOWEK - gracz wrócił bezpiecznie do drzewa!
	GlobalLevelManager.stored_player = null

	_reset_player_for_respawn(player, force_teleport)
	_position_player(player, region, target_door)
	_apply_region_entry_effects(player, region)

## Łączy sygnał spawnowania gracza z obsługą mapy, jeśli nie jest już podłączony.
func _connect_spawn_request(player: PlayerCharacter, callback: Callable) -> void:
	if not player.entity_spawn_requested.is_connected(callback):
		player.entity_spawn_requested.connect(callback)

## Dodaje gracza do kontenera encji pokoju albo bezpośrednio do pokoju.
func _attach_player_to_region(player: PlayerCharacter, region: MapRegion) -> void:
	# Szukamy węzła Y-Sort i dodajemy gracza
	var target_parent = region.find_child("Entities")
	if not target_parent:
		target_parent = region
	target_parent.add_child(player)

## Resetuje stan gracza tylko przy wymuszonym teleportowaniu, takim jak respawn.
func _reset_player_for_respawn(player: PlayerCharacter, force_teleport: bool) -> void:
	# --- ROZDZIELENIE LOGIKI: Zamiast grzebać w zmiennych gracza, prosimy go o reset ---
	# Ekran w tym momencie jest całkowicie czarny!
	if force_teleport and player.has_method("reset_state_for_respawn"):
		player.reset_state_for_respawn()
	# ----------------------------------------------------------------------------------

## Ustawia gracza przy drzwiach albo w domyślnym punkcie spawnu pokoju.
func _position_player(player: PlayerCharacter, region: MapRegion, target_door: Node2D) -> void:
	# --- POPRAWIONE POZYCJONOWANIE (Zwrócony blok obsługujący RESPawn!) ---
	if target_door:
		if "spawn_point" in target_door and target_door.spawn_point != null:
			if target_door is Door and target_door.spawn_point.position.length() > 5.0:
				_set_player_to_door_spawn_point(player, target_door)
			elif target_door is Door:
				_push_player_inside_from_door(player, target_door)
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

## Ustawia gracza w przypisanym punkcie spawnu drzwi.
func _set_player_to_door_spawn_point(player: PlayerCharacter, target_door: Node2D) -> void:
	player.global_position = target_door.spawn_point.global_position

## Odsuwa gracza od drzwi, gdy przypisany punkt spawnu jest niezdefiniowany.
func _push_player_inside_from_door(player: PlayerCharacter, target_door: Door) -> void:
	var inward_dir = -Vector2(target_door.get_direction_offset())
	var safe_push_distance = 64.0
	player.global_position = target_door.global_position + (inward_dir * safe_push_distance)

## Nakłada aury środowiskowe i klątwy przypisane do pokoju.
func _apply_region_entry_effects(player: PlayerCharacter, region: MapRegion) -> void:
	# Nakładamy nowe efekty typu AURA (nieskończone)
	_apply_ambient_aura_effects(player, region)

	# Nakładamy efekty typu KLĄTWA (Zostają po wyjściu)
	_apply_sticky_entry_effects(player, region)

## Nakłada kopie aur środowiskowych jako efekty nieskończone.
func _apply_ambient_aura_effects(player: PlayerCharacter, region: MapRegion) -> void:
	for effect in region.ambient_aura_effects:
		if effect != null:
			var infinite_effect = effect.duplicate()

			# --- NOWE PODEJŚCIE: Używamy nowej flagi nieskończoności ---
			if "is_infinite" in infinite_effect:
				infinite_effect.is_infinite = true

			_apply_entry_effect(player, infinite_effect, true)

## Nakłada kopie klątw wejściowych z ich standardowym czasem trwania.
func _apply_sticky_entry_effects(player: PlayerCharacter, region: MapRegion) -> void:
	for effect in region.sticky_entry_effects:
		if effect != null:
			var normal_effect = effect.duplicate()
			# Klątwy z pułapek normalnie nałożymy przez receive_effect,
			# aby gracz MÓGŁ wyleczyć je np. antidotum po wybiegnięciu z pokoju.
			_apply_entry_effect(player, normal_effect, false)

## Wybiera dostępny interfejs odbioru efektu, zachowując obsługę starszych metod.
func _apply_entry_effect(player: Node, effect: Effect, is_environment_aura: bool) -> void:
	if player.has_method("receive_map_entry_effect"):
		player.call("receive_map_entry_effect", effect, is_environment_aura)
	elif is_environment_aura and player.has_method("receive_environment_effect"):
		player.call("receive_environment_effect", effect)
	elif player.has_method("receive_effect"):
		player.call("receive_effect", effect)
