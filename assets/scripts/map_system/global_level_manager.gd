extends Node

## ID wejścia, w którym gracz ma się pojawić po załadowaniu nowej mapy
var target_entrance_id: String = ""

## Blokada zapobiegająca wielokrotnemu wywołaniu zmiany poziomu
var is_changing_level: bool = false

# --- SŁOWNIK POZIOMÓW ---
## Trzyma wygenerowane instancje map (Node2D), które mają zachowywać swój stan w RAM-ie 
## podczas jednej sesji gry (np. między respawnami). Kluczem jest ścieżka do pliku (.tscn)
var _cached_persistent_levels: Dictionary = {}

## --- NOWOŚĆ: TŁUMACZ ŚCIEŻEK (Translacja UID na RES) ---
func get_normalized_path(path: String) -> String:
	if path.begins_with("uid://"):
		var id = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return path

func change_level_by_path(level_path: String, entrance_id: String) -> void:
	if is_changing_level:
		return
		
	# ZAWSZE normalizujemy ścieżkę na samym początku!
	var resolved_path = get_normalized_path(level_path)
		
	is_changing_level = true
	target_entrance_id = entrance_id
	
	var tree = get_tree()
	var player = tree.get_first_node_in_group("Player")
	
	# 1. ZAMRAŻAMY GRACZA I ZERUJEMY JEGO PĘD
	if player:
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		
		if player.has_method("clear_all_environment_effects"):
			player.clear_all_environment_effects()
		
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		
		var current_parent = player.get_parent()
		if current_parent:
			current_parent.remove_child(player)
		tree.root.add_child(player)
	
	# 2. ŚCIEMNIENIE EKRANU
	TransitionManager.fade_to_black(0.3)
	await TransitionManager.on_fade_out_finished
	
	# 3. ZARZĄDZANIE STARĄ MAPĄ
	var main_scene = tree.current_scene
	var level_container = main_scene.find_child("LevelContainer", true, false)
	
	if level_container:
		var current_map = level_container.get_child(0) if level_container.get_child_count() > 0 else null
		if current_map and current_map is Map:
			level_container.remove_child(current_map)
			
			if not current_map.is_persistent_level:
				current_map.queue_free()
			else:
				# Ujednolicamy klucz zapisu do RAM-u
				var save_key = get_normalized_path(current_map.source_level_path)
				if save_key == "":
					push_error("BŁĄD: Próba zapisu mapy do RAM, która nie ma przypisanego source_level_path!")
					current_map.queue_free()
				else:
					_cached_persistent_levels[save_key] = current_map
					print("GlobalLevelManager: Zamrożono poziom w RAM pod kluczem: ", save_key)
	else:
		push_error("GlobalLevelManager: Nie znaleziono węzła 'LevelContainer'!")
		is_changing_level = false
		return

	# 4. ŁADOWANIE NOWEJ MAPY
	var new_map_instance: Node = null
	
	# ZMIANA: Szukamy używając wyczyszczonego klucza `res://`
	if _cached_persistent_levels.has(resolved_path):
		print("GlobalLevelManager: Przywracam mapę z pamięci podręcznej RAM: ", resolved_path)
		new_map_instance = _cached_persistent_levels[resolved_path]
	else:
		if not ResourceLoader.exists(resolved_path):
			push_error("GlobalLevelManager: Plik mapy nie istnieje: " + resolved_path)
			is_changing_level = false
			return
			
		var scene_to_load = load(resolved_path) as PackedScene
		if scene_to_load:
			print("GlobalLevelManager: Generuję całkowicie nową mapę z dysku: ", resolved_path)
			new_map_instance = scene_to_load.instantiate()
			if new_map_instance is Map:
				new_map_instance.source_level_path = resolved_path 

	# 5. AKTYWACJA I WZNOWIENIE
	if new_map_instance:
		new_map_instance.name = "Map" 
		level_container.add_child(new_map_instance)
		
		# Tylko dla wczytanych map z RAM-u wywołujemy inicjalizację odbioru gracza
		if _cached_persistent_levels.has(resolved_path):
			if new_map_instance.has_method("initialize_level"):
				new_map_instance.initialize_level()
	
	is_changing_level = false
	
func clear_level_cache() -> void:
	for map_node in _cached_persistent_levels.values():
		if is_instance_valid(map_node):
			map_node.queue_free()
	_cached_persistent_levels.clear()
