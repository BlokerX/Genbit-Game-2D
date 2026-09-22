extends Node

var maps_folder = "res://assets/scenes/maps/"
var output_folder = "res://assets/scenes/maps/minimaps_generated_data/"
var padding = 256
var max_image_size = 8192

# Tu będziemy trzymać dane o ofsecie i skali każdej mapy
var metadata = {}

func _ready():
	# 1. Tworzenie folderu wyjściowego, jeśli nie istnieje
	var dir = DirAccess.open(maps_folder)
	if dir and not dir.dir_exists("minimaps_generated_data"):
		dir.make_dir("minimaps_generated_data")
		
	# Odpalamy generator z lekkim opóźnieniem, aby edytor zdążył przygotować środowisko
	call_deferred("_process_all_maps")

func _process_all_maps():
	var dir = DirAccess.open(maps_folder)
	if not dir:
		print("Błąd: Nie znaleziono folderu ", maps_folder)
		return
		
	var map_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Zbieranie wszystkich plików .tscn w głównym folderze map
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			map_files.append(maps_folder + file_name)
		file_name = dir.get_next()
		
	print("--- ROZPOCZYNAM GENEROWANIE MINIMAP (Znaleziono %d map) ---" % map_files.size())
	
	# Przetwarzanie każdej mapy z zachowaniem kolejności
	for map_path in map_files:
		await _process_single_map(map_path)
		
	# ZAPIS METADANYCH (Klucz całego systemu)
	var json_path = output_folder + "minimaps_metadata.json"
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		# Zapisujemy nasz słownik w ładnie sformatowanym JSONie
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()
		print("Zapisano bazę danych minimapy do: ", json_path)
		
	print("--- ZAKOŃCZONO PROCES BATCH-GENERACJI! ---")
	get_tree().quit()

func _process_single_map(map_path: String):
	print("Przetwarzanie: ", map_path.get_file(), " ...")
	
	var map_scene = load(map_path) as PackedScene
	if not map_scene: return
	
	# Tworzymy instancję mapy. Silnik automatycznie odpali w niej _ready(),
	# a pokoje uruchomią calculate_room_bounds() przeliczając size_px.
	var map_instance = map_scene.instantiate()
	add_child(map_instance)
	
	# Wymuszamy odczekanie klatki, żeby cały kod Room.gd i TileMapy na pewno się załadował
	await get_tree().process_frame 
	
	var min_x = INF; var min_y = INF; var max_x = -INF; var max_y = -INF
	var rooms_found = false
	
	var rooms = map_instance.find_children("*", "Room", true, false)
	for room in rooms:
		# NOWOŚĆ: Sprawdzamy flagę
		if "is_mappable" in room and not room.is_mappable:
			room.hide() # Znika z widoku kamery fotografującej
			continue    # Pomijamy go w matematyce (nie powiększy nam kadru)
			
		if "size_px" in room:
			rooms_found = true
			var start_px = room.global_position
			var end_px = room.global_position + room.size_px
			
			min_x = min(min_x, start_px.x)
			min_y = min(min_y, start_px.y)
			max_x = max(max_x, end_px.x)
			max_y = max(max_y, end_px.y)

	if not rooms_found:
		print(" > Pominięto (brak mapowalnych pokoi)")
		map_instance.queue_free()
		return
		
	min_x -= padding; min_y -= padding; max_x += padding; max_y += padding
	
	var real_world_size = Vector2(max_x - min_x, max_y - min_y)
	var capture_offset = Vector2(min_x, min_y)
	
	# MATEMATYKA SKALOWANIA (Automatyczna dla każdej mapy indywidualnie)
	var zoom_factor = 1.0
	if real_world_size.x > max_image_size or real_world_size.y > max_image_size:
		var scale_x = float(max_image_size) / real_world_size.x
		var scale_y = float(max_image_size) / real_world_size.y
		zoom_factor = min(scale_x, scale_y)
		
	var final_image_size = Vector2i(real_world_size * zoom_factor)
	var scale_for_minimap = 1.0 / zoom_factor
	
	var vp = SubViewport.new()
	vp.size = final_image_size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	var cam = Camera2D.new()
	cam.position = capture_offset + (real_world_size / 2.0)
	cam.zoom = Vector2(zoom_factor, zoom_factor)
	vp.add_child(cam)
	
	# Przepinamy mapę do Wirtualnego Płótna
	map_instance.reparent(vp)
	add_child(vp)
	
	# Czekamy na wyrenderowanie tekstury przez GPU
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	
	var tex = vp.get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			var base_name = map_path.get_file().get_basename()
			var relative_png_path = output_folder + base_name + "_minimap.png"
			
			img.save_png(relative_png_path)
			
			# Dopisywanie danych do słownika JSON. Kluczem jest absolutna ścieżka do mapy.
			metadata[map_path] = {
				"texture_path": relative_png_path,
				"offset_x": capture_offset.x,
				"offset_y": capture_offset.y,
				"scale": scale_for_minimap
			}
			print(" > Sukces. Skala: ", snapped(zoom_factor, 0.01))
			
	# Czyszczenie pamięci przed załadowaniem kolejnej mapy z pętli
	vp.queue_free()
