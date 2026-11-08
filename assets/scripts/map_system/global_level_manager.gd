extends Node
## Globalny menedżer przejść między całymi poziomami (plikami .tscn) oraz pamięci podręcznej trwałych map.

const LEVEL_FADE_OUT_DURATION_SEC: float = 0.3
const LEVEL_ARRIVAL_UNLOCK_DELAY_SEC: float = 0.5

## Schowek na gracza, gdy jest wycięty z drzewa podczas ładowania nowego poziomu.
var stored_player: Node2D = null
## ID wejścia, w którym gracz ma się pojawić po załadowaniu nowej mapy.
var target_entrance_id: String = ""
## Konkretne wejście docelowe blokujące kolejne portale do czasu opuszczenia strefy.
var arrival_entrance: LevelEntrance
## Blokada zapobiegająca wielokrotnemu wywołaniu zmiany poziomu.
var is_changing_level: bool = false
## Numer bieżącej operacji transferu, unieważniający transfery po resecie sesji.
var _level_change_generation: int = 0

# --- SŁOWNIK POZIOMÓW ---
## Trzyma wygenerowane instancje map (Node2D), które mają zachowywać swój stan w RAM-ie 
## podczas jednej sesji gry (np. między wypadami do lochów). Kluczem jest znormalizowana ścieżka (.tscn).
var _cached_persistent_levels: Dictionary = {}

## Tłumacz ścieżek (Translacja UID na czytelne res://)
func get_normalized_path(path: String) -> String:
	if path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return path

func change_level_by_path(level_path: String, entrance_id: String) -> void:
	if is_changing_level:
		return

	var resolved_path: String = get_normalized_path(level_path)
	is_changing_level = true
	_level_change_generation += 1
	var change_generation: int = _level_change_generation
	target_entrance_id = entrance_id
	arrival_entrance = null

	var tree: SceneTree = get_tree()
	var player: Node2D = tree.get_first_node_in_group("Player") as Node2D

	# 1. ZAMRAŻAMY RUCH GRACZA, ALE NIE ODPINAMY GO JESZCZE OD DRZEWA
	if player != null:
		player.set_physics_process(false)
		if player.has_method("clear_all_environment_effects"):
			player.call("clear_all_environment_effects")
		if "velocity" in player:
			player.set("velocity", Vector2.ZERO)

	# 2. ŚCIEMNIENIE EKRANU
	TransitionManager.fade_to_black(LEVEL_FADE_OUT_DURATION_SEC)
	await TransitionManager.on_fade_out_finished
	if change_generation != _level_change_generation:
		return
	if not is_inside_tree() or not is_instance_valid(tree.current_scene) or not tree.current_scene.is_inside_tree():
		is_changing_level = false
		return

	# 2.5. EKRAN JEST CZARNY - ODPINAMY GRACZA I WYŁĄCZAMY MU PROCESY
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		var current_parent: Node = player.get_parent()
		if current_parent != null:
			current_parent.remove_child(player)
		stored_player = player

	# 3. ZARZĄDZANIE STARĄ MAPĄ
	var main_scene: Node = tree.current_scene
	var level_container: Node = main_scene.find_child("LevelContainer", true, false)

	if level_container != null:
		var current_map: Node = level_container.get_child(0) if level_container.get_child_count() > 0 else null
		if current_map != null and current_map is Map:
			var map_node: Map = current_map as Map
			level_container.remove_child(map_node)

			if not map_node.is_persistent_level:
				map_node.queue_free()
			else:
				var save_key: String = get_normalized_path(map_node.source_level_path)
				if save_key == "":
					push_error("BŁĄD: Próba zapisu mapy do RAM, która nie ma przypisanego source_level_path!")
					map_node.queue_free()
				else:
					_cached_persistent_levels[save_key] = map_node
					print("GlobalLevelManager: Zamrożono poziom w RAM pod kluczem: ", save_key)
	else:
		push_error("GlobalLevelManager: Nie znaleziono węzła 'LevelContainer'!")
		is_changing_level = false
		return

	# 4. ŁADOWANIE NOWEJ MAPY (z RAM-u lub asynchronicznie z dysku - bez zacinania wątku głównego!)
	var new_map_instance: Node = null
	var was_loaded_from_cache: bool = false

	if _cached_persistent_levels.has(resolved_path):
		print("GlobalLevelManager: Przywracam mapę z pamięci podręcznej RAM: ", resolved_path)
		new_map_instance = _cached_persistent_levels[resolved_path]
		was_loaded_from_cache = true
	else:
		if not ResourceLoader.exists(resolved_path):
			push_error("GlobalLevelManager: Plik mapy nie istnieje: " + resolved_path)
			is_changing_level = false
			return

		var scene_to_load: PackedScene = await _load_packed_scene_async(resolved_path)
		if change_generation != _level_change_generation:
			return
		if scene_to_load != null:
			print("GlobalLevelManager: Generuję całkowicie nową mapę z dysku: ", resolved_path)
			new_map_instance = scene_to_load.instantiate()
			if new_map_instance is Map:
				(new_map_instance as Map).source_level_path = resolved_path

	# 5. AKTYWACJA I WZNOWIENIE
	if new_map_instance != null:
		new_map_instance.name = "Map"
		level_container.add_child(new_map_instance)

		if was_loaded_from_cache and new_map_instance.has_method("initialize_level"):
			new_map_instance.call("initialize_level")

	get_tree().create_timer(LEVEL_ARRIVAL_UNLOCK_DELAY_SEC).timeout.connect(func():
		if change_generation == _level_change_generation:
			is_changing_level = false
	)

## Ładuje zasób PackedScene wielowątkowo w tle (ResourceLoader.load_threaded_request), eliminując zamrożenie okna gry.
func _load_packed_scene_async(path: String) -> PackedScene:
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		return load(path) as PackedScene

	while true:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not is_inside_tree():
				return null
			await get_tree().process_frame
		else:
			return load(path) as PackedScene
	return null

## Rejestruje portal, do którego właśnie przenoszony jest gracz.
func register_arrival_entrance(entrance: LevelEntrance) -> void:
	if entrance == null:
		push_error("GlobalLevelManager: Nie można zarejestrować pustego portalu docelowego.")
		return
	arrival_entrance = entrance

## Zwalnia blokadę portali wyłącznie dla portalu docelowego po opuszczeniu jego strefy.
func complete_level_arrival(entrance: LevelEntrance) -> void:
	if entrance == arrival_entrance:
		arrival_entrance = null

## Czyści mapy i gracza przechowywane między poziomami na koniec sesji.
func reset_game_session() -> void:
	_level_change_generation += 1
	clear_level_cache()
	if is_instance_valid(stored_player) and stored_player.get_parent() == null:
		stored_player.queue_free()
	stored_player = null
	target_entrance_id = ""
	arrival_entrance = null
	is_changing_level = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for map_node in _cached_persistent_levels.values():
			if is_instance_valid(map_node) and map_node.get_parent() == null:
				map_node.queue_free()
		if is_instance_valid(stored_player) and stored_player.get_parent() == null:
			stored_player.queue_free()

func clear_level_cache() -> void:
	for map_node in _cached_persistent_levels.values():
		if is_instance_valid(map_node):
			map_node.queue_free()
	_cached_persistent_levels.clear()
