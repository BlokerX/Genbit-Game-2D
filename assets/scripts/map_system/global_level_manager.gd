extends Node

## ID wejścia, w którym gracz ma się pojawić po załadowaniu nowej mapy
var target_entrance_id: String = ""

## Blokada zapobiegająca wielokrotnemu wywołaniu zmiany poziomu
var is_changing_level: bool = false

## Funkcja przyjmująca ścieżkę tekstową zamiast PackedScene
func change_level_by_path(level_path: String, entrance_id: String) -> void:
	if is_changing_level:
		return
		
	is_changing_level = true
	target_entrance_id = entrance_id
	
	var tree = get_tree()
	var player = tree.get_first_node_in_group("Player")
	
	# 1. ZAMRAŻAMY GRACZA I ZERUJEMY JEGO PĘD
	if player:
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Zdejmujemy Aury z poprzedniego poziomu!
		if player.has_method("clear_all_environment_effects"):
			player.clear_all_environment_effects()
		
		# Zerowanie pędu (zakładając standardowy CharacterBody2D z polem velocity)
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		
		var current_parent = player.get_parent()
		if current_parent:
			current_parent.remove_child(player)
		tree.root.add_child(player)
	
	# 2. ŚCIEMNIENIE EKRANU
	TransitionManager.fade_to_black(0.3)
	await TransitionManager.on_fade_out_finished
	
	# 3. BEZPIECZNE ŁADOWANIE PLIKU ZE ŚCIEŻKI TEKSTOWEJ
	
	# ZMIANA TUTAJ: Używamy ResourceLoader zamiast FileAccess!
	# ResourceLoader automatycznie widzi spakowane pliki (.remap) w wyeksportowanej grze.
	if not ResourceLoader.exists(level_path):
		push_error("GlobalLevelManager: Plik mapy nie istnieje pod ścieżką: " + level_path)
		is_changing_level = false
		return
		
	var scene_to_load = load(level_path) as PackedScene
	if not scene_to_load:
		push_error("GlobalLevelManager: Nie udało się załadować PackedScene z pliku: " + level_path)
		is_changing_level = false
		return
	
	# 4. ZNAJDOWANIE KONTENERA W DRZEWIE SCENY
	var main_scene = tree.current_scene
	var level_container = main_scene.find_child("LevelContainer", true, false)
	
	if level_container:
		# Natychmiastowe wypięcie i usunięcie starego poziomu, żeby zwolnić nazwę "Map"
		for child in level_container.get_children():
			level_container.remove_child(child)
			child.queue_free()
			
		# Tworzymy nową mapę
		var new_map_instance = scene_to_load.instantiate()
		
		# Nadajemy czystą nazwę "Map"
		new_map_instance.name = "Map"
		
		level_container.add_child(new_map_instance)
	else:
		push_error("GlobalLevelManager: Nie znaleziono węzła 'LevelContainer'!")
	
	is_changing_level = false
