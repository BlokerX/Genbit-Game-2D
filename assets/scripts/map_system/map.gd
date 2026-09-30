extends Node2D
## Klasa poziomu, przechowywująca pokoje na poziomie
class_name Map

# --- STAŁE (Wyeliminowanie magicznych stringów) ---
## Grupa gracza
const PLAYER_GROUP = "Player"

## Sygnał zmiany pokoju
signal map_region_changed(new_map_region: MapRegion)

## Sygnał aktualizacji mapy (UI)
signal map_updated()

@export_group("Ustawienia zapisu (Czy level jest zapamiętywany po wyjściu)")
## Jeśli TRUE: Pokoje wewnątrz tego poziomu będą zarządzane przez SaveManagera.
## Zabite potwory, zniszczone skrzynie i upuszczony loot ZOSTANĄ NA ZAWSZE w pliku save'a.
## Jeśli FALSE: To jest "Dungeon". Wszystko wraca do normy po wyjściu z mapy.
@export var is_persistent_level: bool = true

@export_group("Główne Obiekty")
## Pokój startowy
@export var starting_map_region: MapRegion


@export_group("Ustawienia Respawnu")
## Czy po respawnie wyczyścić historię odkrytych i odwiedzonych pokoi na minimapie?
@export var reset_map_history_on_respawn: bool = true

## Czy całkowicie zresetować poziom (przeładować aktualną scenę gry)?
## UWAGA: Przeładowanie sceny zresetuje też statystyki/ekwipunek gracza do wartości początkowych.
@export var reload_entire_scene_on_respawn: bool = false # TODO czy to jest ważne czy martwy kod?

## Wewnętrzna zmienna systemowa: Gwarantuje, że RAM wie, skąd wzięła się ta mapa.
## (Nie zmieniaj tego ręcznie!)
var source_level_path: String = "" # TODO czy to jest martwy kod czy ma jakąś funkcję?

## Obecny pokój na scenie
var current_map_region: MapRegion
## Wszystkie pokoje
var all_map_regions: Array[MapRegion] = []
## Odkryte pokoje (widoczne na mapie)
var discovered_map_regions: Array[MapRegion] = []
## Pokoje odwiedzone
var visited_map_regions: Array[MapRegion] = []

# Słownik przestrzenny (Grid)
## Kluczem jest Vector2i (np. Vector2i(0,0)), a wartością obiekt MapRegion
var map_region_grid: Dictionary = {}

## Węzeł zaciemniający całą planszę (sterowany płynnie)
var global_darkness: CanvasModulate

@export_group("Generacja Drzwi")
## Scena drzwi, która ma być automatycznie wstawiana do pokoi
@export var auto_door_scene: PackedScene

## Domyślna tekstura drzwi dla CAŁEJ MAPY. 
## Zostanie użyta w zwykłych pokojach, nadpisując podstawowy wygląd drzwi z pliku.
@export var default_map_door_texture: Texture2D

func _ready() -> void:
	add_to_group("Map") # Wymuszenie grupy
	
	# --- GLOBALNY MROK ---
	global_darkness = CanvasModulate.new()
	global_darkness.name = "GlobalDarkness"
	global_darkness.color = Color.WHITE
	add_child(global_darkness)
	# ---------------------
	
	# Rejestracja i ustawianie pokoi
	for child in get_children():
		if child is MapRegion:
			register_map_region(child)
			# Ukrywamy wszystko oprócz pokoju startowego, by nie obciążać silnika
			if child != starting_map_region:
				remove_child(child)
	
	# 1. NAJPIERW z centralnego poziomu spawnujemy fizyczne drzwi tam, gdzie oba pokoje się zgadzają
	_auto_spawn_missing_doors()
	# 2. POTEM Auto-Linker zszywa wszystkie drzwi (te wstawione ręcznie i te wstawione przez automat)
	_auto_link_doors()
	
	initialize_level()

func initialize_level() -> void:
	# --- SYSTEM ODBIERANIA GRACZA Z INNEGO POZIOMU ---
	var map_region_to_load: MapRegion = starting_map_region
	var spawn_node: Node2D = null
	
	# Sprawdzamy, czy w GlobalLevelManagerze jest zapisany cel podróży
	if GlobalLevelManager.target_entrance_id != "":
		var entrance = _find_entrance_by_id(GlobalLevelManager.target_entrance_id)
		if entrance:
			# Znaleźliśmy nasze wejście! Szukamy, w którym pokoju ono leży.
			map_region_to_load = _get_map_region_of_node(entrance)
			spawn_node = entrance
			
			# --- NAPRAWA PĘTLI TELEPORTACJI ---
			# Ponieważ portal przywracany z RAM-u nie odpala funkcji _ready(),
			# musimy ręcznie powiedzieć mu, że gracz właśnie na niego spadł, 
			# aby nie odesłał go od razu z powrotem.
			entrance.has_triggered = true
			# ----------------------------------
			
		else:
			push_error("Map: Nie znaleziono wejścia o ID: " + GlobalLevelManager.target_entrance_id)
			
		# Czyścimy ID w chmurze, żeby przy kolejnym respawnie (np. po śmierci) nie psuło logiki
		GlobalLevelManager.target_entrance_id = ""
	else:
		# Wymuszenie czarnego ekranu przy pierwszym wczytaniu gry, aby ukryć reset kamery
		TransitionManager.color_rect.color = Color.BLACK
		
	# Ładujemy ustalony pokój i WWRZUCAMY do niego wyjętego wcześniej gracza
	if map_region_to_load:
		# Ustawiamy natychmiastowy kolor mroku dla pierwszego pokoju
		global_darkness.color = map_region_to_load.darkness_color if map_region_to_load.is_dark_map_region else Color.WHITE
		
		if not map_region_to_load.is_inside_tree():
			add_child(map_region_to_load)
		
		# --- NOWOŚĆ: PRE-POZYCJONOWANIE GRACZA ---
		# (Żeby od samej pierwszej klatki kamera widziała poprawne koordynaty zamiast tych z Volcano)
		var player = get_player()
		if player:
			if spawn_node:
				player.global_position = spawn_node.global_position
			elif map_region_to_load.spawn_points.size() > 0:
				player.global_position = map_region_to_load.spawn_points[0].global_position
		# ----------------------------------------
		
		# Wywołujemy change_map_region. Nasza funkcja w map.gd automatycznie 
		# znajdzie gracza (nawet jeśli był tymczasowo w root) i wsadzi go do "Entities"!
		call_deferred("change_map_region", map_region_to_load, spawn_node, true)
		
		# WAŻNE: Usunięto TransitionManager.fade_to_normal(0.4) stąd, 
		# ponieważ change_map_region robi to w bezpieczniejszym momencie.

## Funkcja pomocnicza: Szuka po ID wejścia na całej mapie
func _find_entrance_by_id(id: String) -> LevelEntrance:
	for map_region in all_map_regions:
		# Przeszukujemy dzieci pokoju w poszukiwaniu klasy LevelEntrance
		for child in map_region.find_children("*", "LevelEntrance", true, false):
			if child.my_entrance_id == id:
				return child as LevelEntrance
	return null

## Funkcja pomocnicza: Zwraca pokój, do którego należy dany węzeł
func _get_map_region_of_node(node: Node) -> MapRegion:
	var current = node
	while current != null:
		if current is MapRegion:
			return current
		current = current.get_parent()
	return null

# --- FUNKCJE DYNAMIKI MAPY ---

## Rejestracja pokoju, przypisuje go do list pokoi i aktualizuje mapę
func register_map_region(map_region: MapRegion) -> void:
	if not all_map_regions.has(map_region):
		all_map_regions.append(map_region)
		
		# Zapisujemy pokój w siatce (Grid)
		# Używamy zmiennej map_position z map_region.gd jako klucza
		map_region_grid[map_region.map_position] = map_region
		
		map_updated.emit()

## Funkcja do dynamicznego usuwania pokoju (np. pokój się zapadł/zniszczył)
func unregister_map_region(map_region: MapRegion) -> void:
	if all_map_regions.has(map_region):
		all_map_regions.erase(map_region)
	
	if discovered_map_regions.has(map_region):
		discovered_map_regions.erase(map_region)
		
	# Usunięcie z listy odwiedzonych przy kasowaniu pokoju
	if visited_map_regions.has(map_region):
		visited_map_regions.erase(map_region)
	
	# Usuwamy pokój z siatki
	if map_region_grid.has(map_region.map_position) and map_region_grid[map_region.map_position] == map_region:
		map_region_grid.erase(map_region.map_position)
	
	map_updated.emit() # Informujemy UI o zmianie

## Odwiedzenie pokoju (dodaje do listy odwiedzonych)
func discover_map_region(map_region: MapRegion) -> void:
	if not discovered_map_regions.has(map_region):
		discovered_map_regions.append(map_region)
		map_updated.emit() # Odświeżamy mapę po odkryciu

## Zwraca pokój w którym znajdują się drzwi
func find_map_region_by_door(target_door: Door) -> MapRegion:
	for map_region in all_map_regions:
		# Sprawdzamy czy te konkretne drzwi należą do tego pokoju
		# Nawet jeśli pokój jest poza drzewem sceny, ta funkcja zadziała
		if map_region.is_ancestor_of(target_door):
			return map_region
	return null

## Odkrywa wszystkie pokoje sąsiadujące z podanym pokojem (poprzez połączone drzwi)
func _discover_neighboring_map_regions(map_region: MapRegion) -> void:
	for door in map_region.doors:
		if door.destination_door:
			# Szukamy pokoju, w którym znajdują się drzwi docelowe
			var neighbor_map_region = find_map_region_by_door(door.destination_door)
			# Sprawdzamy, czy pokój istnieje i CZY NIE JEST oznaczony jako sekretny
			if neighbor_map_region and not neighbor_map_region.is_secret:
				discover_map_region(neighbor_map_region) # Odkrywamy go na mapie

## Funkcja zmiany pokoju
func change_map_region(new_map_region: MapRegion, target_door: Node2D = null, force_teleport: bool = false) -> void:
	# 1. NAJPIERW ŁAPIEMY GRACZA! Zanim cokolwiek usuniemy.
	var player = get_player()
	
	var old_map_region = current_map_region
	# Zabezpieczenie przed usuwaniem pokoju, w którym już jesteśmy (Respawn)
	var is_same_map_region = (old_map_region == new_map_region)
	
	# ODCZYTANIE TRYBU Z NOWEGO POKOJU (Zabezpieczenie: FADE jako domyślny)
	var mode = new_map_region.transition_mode if "transition_mode" in new_map_region else 0
	var do_fade = (mode == 0 or mode == 2) # FADE lub BOTH
	var do_slide = (mode == 1 or mode == 2) # SLIDE lub BOTH
	
	# Zabezpieczenie: jeśli wymuszamy teleport, wyłączamy Slide i upewniamy się, że ekran zgaśnie
	if old_map_region == null or is_same_map_region or force_teleport:
		do_slide = false
		do_fade = true
	
	# ZAMROŻENIE GRACZA NA CZAS ZMIANY
	if player:
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)

	# ŚCIEMNIENIE EKRANU
	if do_fade:
		TransitionManager.fade_to_black()
		await TransitionManager.on_fade_out_finished
	
	# --- TUTAJ GRA JEST CAŁKOWICIE ZAKRYTA CZERNIĄ LUB GOTOWA DO PRZESUNIĘCIA ---
	current_map_region = new_map_region
	
	# TERAZ bezpiecznie wyłączamy fizykę graczowi i staremu pokojowi
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if old_map_region and not is_same_map_region:
		old_map_region.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Ściągamy efekty środowiskowe starego pokoju z gracza (TYLKO AURĘ!)
	if old_map_region and player:
		for effect in old_map_region.ambient_aura_effects:
			if effect != null:
				player.remove_effect_by_name(effect.effect_name)
	
	# Zabezpieczamy gracza: wyciągamy go ze starego pokoju
	if player and player.get_parent():
		player.get_parent().remove_child(player)

	# 2. OBLICZANIE WEKTORA PRZESUNIĘCIA (Jeśli to tryb SLIDE/BOTH)
	var slide_vector = Vector2.ZERO
	if do_slide and target_door and old_map_region and not is_same_map_region:
		if target_door is Door:
			var dir_offset = target_door.get_direction_offset()
			slide_vector = Vector2(-dir_offset.x * current_map_region.size_px.x, -dir_offset.y * current_map_region.size_px.y)

	# 3. Dodajemy nowy pokój do sceny
	current_map_region.position = slide_vector # Ustawia offset jeśli SLIDE, inaczej Vector2.ZERO
	current_map_region.visible = true
	
	if not current_map_region.is_inside_tree():
		add_child(current_map_region)
		
	# Usuwamy stary pokój tylko jeśli to był INNY pokój
	if not do_slide and old_map_region and not is_same_map_region:
		old_map_region.process_mode = Node.PROCESS_MODE_INHERIT
		_disconnect_door_signals(old_map_region)
		if old_map_region.is_inside_tree():
			remove_child(old_map_region)
		
	_connect_door_signals(current_map_region)
	discover_map_region(current_map_region)
	_discover_neighboring_map_regions(current_map_region)
	
	if not visited_map_regions.has(current_map_region):
		visited_map_regions.append(current_map_region)
	
	map_region_changed.emit(current_map_region)
	
	# 4. UMIESZCZAMY GRACZA W NOWYM POKOJU
	if player:
		if not player.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
			player.entity_spawn_requested.connect(_on_entity_spawn_requested)
		
		# Szukamy węzła Y-Sort i dodajemy gracza
		var target_parent = current_map_region.find_child("Entities")
		if not target_parent:
			target_parent = current_map_region
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
			if current_map_region.spawn_points.size() > 0:
				player.global_position = current_map_region.spawn_points[0].global_position
			else:
				player.global_position = current_map_region.global_position + (current_map_region.size_px / 2.0)
		# ------------------------------------------------------------------------
		
		# Nakładamy nowe efekty typu AURA (nieskończone)
		for effect in current_map_region.ambient_aura_effects:
			if effect != null:
				var infinite_effect = effect.duplicate()
				
				# --- NOWE PODEJŚCIE: Używamy nowej flagi nieskończoności ---
				if "is_infinite" in infinite_effect:
					infinite_effect.is_infinite = true
				
				# --- ZMIANA: Używamy nowej, nieuleczalnej funkcji! ---
				if player.has_method("receive_environment_effect"):
					player.receive_environment_effect(infinite_effect)
				else:
					player.receive_effect(infinite_effect)
				
		# Nakładamy efekty typu KLĄTWA (Zostają po wyjściu)
		for effect in current_map_region.sticky_entry_effects:
			if effect != null:
				var normal_effect = effect.duplicate()
				# Klątwy z pułapek normalnie nałożymy przez receive_effect, 
				# aby gracz MÓGŁ wyleczyć je np. antidotum po wybiegnięciu z pokoju.
				player.receive_effect(normal_effect)
		
	# 5. Odpalamy logikę walki / blokady pokoju
	current_map_region.check_and_lock_map_region()
	
	# 6. Informujemy gracza o strefie pacyfizmu
	if player and "is_in_pacifist_zone" in player:
		player.is_in_pacifist_zone = current_map_region.pacifist_zone
	
	# --- 7. FAZA ANIMACJI, ROZJAŚNIANIA I ŚWIATEŁ ---
	
	# Jeśli BOTH, zaczynamy rozjaśniać w tle w trakcie przesuwania
	if do_fade and do_slide:
		TransitionManager.fade_to_normal()
		await TransitionManager.on_fade_in_finished
		
	if do_slide:
		# ANIMACJA PRZESUWANIA (TWEEN)
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var anim_duration = 0.45
		
		tween.tween_property(current_map_region, "position", Vector2.ZERO, anim_duration)
		if old_map_region and not is_same_map_region:
			tween.tween_property(old_map_region, "position", -slide_vector, anim_duration)
			
		# --- SYSTEM PŁYNNEGO PRZEJŚCIA ŚWIATEŁ ---
		# 1. Płynna zmiana mroku całej planszy
		var target_color = current_map_region.darkness_color if current_map_region.is_dark_map_region else Color.WHITE
		tween.tween_property(global_darkness, "color", target_color, anim_duration)
		
		# 2. Wygaszamy starą latarkę, żeby nie świeciła do nowego pokoju
		if old_map_region and not is_same_map_region:
			var old_light = old_map_region.find_child("CenterMapRegionLight", false, false)
			if old_light and old_light is PointLight2D:
				tween.tween_property(old_light, "energy", 0.0, anim_duration)
				
		# 3. Płynnie zapalamy nową latarkę
		var new_light = current_map_region.find_child("CenterMapRegionLight", false, false)
		if new_light and new_light is PointLight2D:
			new_light.energy = 0.0 # Zaczynamy od zgaszonej
			tween.tween_property(new_light, "energy", current_map_region.center_light_energy, anim_duration)
		# -----------------------------------------
			
		await tween.finished
		
		# Sprzątanie starego pokoju PO ANIMACJI
		if old_map_region and not is_same_map_region:
			old_map_region.process_mode = Node.PROCESS_MODE_INHERIT # Przywracamy fizykę dla historii odwiedzonych
			_disconnect_door_signals(old_map_region)
			if old_map_region.is_inside_tree():
				remove_child(old_map_region)
			old_map_region.position = Vector2.ZERO 
			
	else:
		# Jeśli TYLKO FADE, stary pokój zniknął wyżej, zostaje tylko rozjaśnić obraz
		var target_color = current_map_region.darkness_color if current_map_region.is_dark_map_region else Color.WHITE
		global_darkness.color = target_color
		
		if do_fade:
			TransitionManager.fade_to_normal()
			await TransitionManager.on_fade_in_finished

	# 8. ODMROŻENIE GRACZA (Przywrócenie fizyki po wszystkich animacjach!)
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if player.has_method("set_physics_process"):
			player.set_physics_process(true)

## Obsługa spawnowania gracza z sygnału
func _on_entity_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	if not is_inside_tree():
		return
	
	if current_map_region:
		var target_parent = current_map_region.find_child("Entities")
		if not target_parent: target_parent = current_map_region
		
		target_parent.add_child(spawned_node)
		spawned_node.global_position = spawn_pos
		
		# Odsyłamy do streamera
		var streamer = current_map_region.get_node_or_null("WorldStreamer")
		if current_map_region.map_region_type == MapRegion.MapRegionType.OPEN_WORLD and streamer and streamer.has_method("register_entity"):
			streamer.register_entity(spawned_node)
	else:
		get_tree().current_scene.add_child(spawned_node)
		spawned_node.global_position = spawn_pos

## Podłączenie sygnału do drzwi
func _connect_door_signals(map_region: MapRegion) -> void:
	# MapRegion sam pobiera swoje drzwi w _ready lub auto_fetch
	for door in map_region.doors:
		if not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

## Odłączenie sygnału od drzwi
func _disconnect_door_signals(map_region: MapRegion) -> void:
	for door in map_region.doors:
		if door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

## Obługa sygnału wejścia w drzwi
func _on_door_entered(door: Door) -> void:
	# Sprawdzamy, czy te drzwi w ogóle gdzieś prowadzą
	if door.destination_door:
		# Używamy naszej nowej funkcji przeszukującej listę all_map_regions
		var next_map_region = find_map_region_by_door(door.destination_door)
		
		if next_map_region:
			call_deferred("change_map_region", next_map_region, door.destination_door)
		else:
			push_warning("Map: Drzwi docelowe nie znajdują się w żadnym węźle MapRegion!")
	else:
		push_warning("Map: Gracz wszedł w drzwi, ale nie przypisano im destination_door w edytorze.")

## Funkcja wywoływana, gdy gracz zostanie zrespawnowany
func handle_player_respawn(player: PlayerCharacter) -> void:
	print("Menedżer Mapy: Gracz zainicjował respawn...")
	
	if starting_map_region:
		if is_persistent_level:
			print("Menedżer Mapy: Reset trwałej mapy. Oczekuję na mechanikę SaveManager'a...")
		else:
			print("Menedżer Mapy: Miękki reset...")
			
		# Używamy AWAIT i przekazujemy 1.0s na powolne, gładkie przejście
		await change_map_region(starting_map_region, null, true)
		
		# Obsługa flagi historii mapy
		if reset_map_history_on_respawn:
			discovered_map_regions.clear()
			visited_map_regions.clear()
			discover_map_region(starting_map_region)
		else:
			discover_map_region(starting_map_region)
			
		map_updated.emit()
	else:
		push_error("Menedżer Mapy: Brak 'starting_map_region'. Twardy reset sceny.")
		get_tree().reload_current_scene()

## Zwrócenie gracza ze sceny lub ze schowka (między-poziomowego)
func get_player() -> PlayerCharacter:
	# 1. Próbujemy znaleźć gracza normalnie w drzewie
	var player = get_tree().get_first_node_in_group(PLAYER_GROUP)
	
	# 2. Jeśli go nie ma, bo ładuje się poziom, bierzemy go ze schowka Menedżera!
	if player == null and GlobalLevelManager.get("stored_player") != null:
		player = GlobalLevelManager.stored_player
		
	return player as PlayerCharacter

# Odpala się automatycznie, gdy węzeł mapy opuszcza ekran (np. trafia do "zamrażarki" RAM-u)
func _exit_tree() -> void:
	# --- NAPRAWA 1: Bezpiecznie odpinamy gracza, niczego nie niszczymy! ---
	var player = get_player()
	if player and player.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
		player.entity_spawn_requested.disconnect(_on_entity_spawn_requested)

# Wbudowana funkcja silnika Godot, która odpala się w momencie niszczenia obiektu przez GC
func _notification(what: int) -> void:
	# --- NAPRAWA 2: Prawdziwe czyszczenie pamięci ---
	# NOTIFICATION_PREDELETE odpala się TYLKO wtedy, gdy cała mapa dostała komendę queue_free()
	# (np. po śmierci przy twardym resecie lub podczas usuwania nietrwałego Dungeonu).
	if what == NOTIFICATION_PREDELETE:
		for map_region in all_map_regions:
			if is_instance_valid(map_region) and map_region.get_parent() == null:
				map_region.queue_free()

## Funkcja do sprawdzania co leży na danym polu
## Zwraca pokój znajdujący się na podanych koordynatach siatki (lub null, jeśli pole jest puste)
func get_map_region_at(coords: Vector2i) -> MapRegion:
	if map_region_grid.has(coords):
		return map_region_grid[coords]
	return null

## Centralny system generowania drzwi. 
func _auto_spawn_missing_doors() -> void:
	if auto_door_scene == null:
		return
	
	# Przeszukujemy każdy pokój na wirtualnej siatce
	for coords in map_region_grid.keys():
		var grid_map_region = map_region_grid[coords]
		
		# KRAWĘDŹ 1: Sprawdzamy sąsiada po PRAWEJ (X+1, Y)
		var right_coords = coords + Vector2i(1, 0)
		if map_region_grid.has(right_coords):
			var right_map_region = map_region_grid[right_coords]
			if grid_map_region.allow_door_right and right_map_region.allow_door_left:
				_sync_door_pair(grid_map_region, Door.Direction.RIGHT, right_map_region, Door.Direction.LEFT)
				
		# KRAWĘDŹ 2: Sprawdzamy sąsiada W DÓŁ (X, Y+1)
		var down_coords = coords + Vector2i(0, 1)
		if map_region_grid.has(down_coords):
			var down_map_region = map_region_grid[down_coords]
			if grid_map_region.allow_door_down and down_map_region.allow_door_up:
				_sync_door_pair(grid_map_region, Door.Direction.DOWN, down_map_region, Door.Direction.UP)


## Inteligentne parowanie drzwi - obie strony przejścia ZAWSZE wyglądają identycznie!
func _sync_door_pair(map_region_a: MapRegion, dir_a: Door.Direction, map_region_b: MapRegion, dir_b: Door.Direction) -> void:
	var door_a = map_region_a.get_door(dir_a)
	var door_b = map_region_b.get_door(dir_b)
	
	# PRIORYTET 1: Oba pokoje mają już Twoje ręczne drzwi. Automat nic nie robi.
	if door_a != null and door_b != null:
		return
		
	# PRIORYTET 2, 3 i 4: Nie ma żadnych ręcznych drzwi - pełen automat.
	if door_a == null and door_b == null:
		# --- KLUCZ: Wyliczamy jedną, najsilniejszą teksturę dla OBU pokoi naraz! ---
		var best_tex = _get_best_door_texture(map_region_a, map_region_b)
		
		# Tworzymy i wstawiamy drzwi z tą samą teksturą po obu stronach ściany
		door_a = map_region_a.spawn_auto_door(dir_a, auto_door_scene, best_tex)
		door_b = map_region_b.spawn_auto_door(dir_b, auto_door_scene, best_tex)
		return 
		
	# PRIORYTET 1 (dziedziczenie): TYLKO Pokój A ma ręczne drzwi. Pokój B musi je skopiować.
	if door_a != null and door_b == null:
		var tex_b = _get_manual_door_texture(door_a)
		door_b = map_region_b.spawn_auto_door(dir_b, auto_door_scene, tex_b)
		
	# PRIORYTET 1 (dziedziczenie): TYLKO Pokój B ma ręczne drzwi. Pokój A musi je skopiować.
	elif door_b != null and door_a == null:
		var tex_a = _get_manual_door_texture(door_b)
		door_a = map_region_a.spawn_auto_door(dir_a, auto_door_scene, tex_a)

## Funkcja pomocnicza: Wylicza "najsilniejszą" teksturę dla całego połączenia
func _get_best_door_texture(map_region_1: MapRegion, map_region_2: MapRegion) -> Texture2D:
	# Priorytet 2: Niestandardowy obrazek z Inspektora (jeśli oba mają, wygrywa ten z lewej/góry)
	if map_region_1.custom_door_texture != null:
		return map_region_1.custom_door_texture
	if map_region_2.custom_door_texture != null:
		return map_region_2.custom_door_texture
		
	# Priorytet 3: Typ pokoju - WALKA NA PUNKTY WAŻNOŚCI
	var weight_1 = _get_map_region_type_weight(map_region_1.map_region_type)
	var weight_2 = _get_map_region_type_weight(map_region_2.map_region_type)
	
	# Jeśli chociaż jeden pokój jest "specjalny" (waga > 0)
	if weight_1 > 0 or weight_2 > 0:
		# Zwycięża ten, który ma więcej punktów!
		if weight_1 >= weight_2:
			return _get_door_texture_for_map_region_type(map_region_1.map_region_type)
		else:
			return _get_door_texture_for_map_region_type(map_region_2.map_region_type)
		
	# Priorytet 4: Domyślna tekstura dla Całej Mapy
	if default_map_door_texture != null:
		return default_map_door_texture
		
	# Priorytet 5: Absolutny domyślny wygląd
	return null

## Funkcja pomocnicza: Ustala, który typ pokoju jest "ważniejszy" przy zderzeniu
func _get_map_region_type_weight(type: MapRegion.MapRegionType) -> int:
	match type:
		MapRegion.MapRegionType.BOSS: 
			return 100 # Boss zawsze dominuje korytarz
		MapRegion.MapRegionType.TREASURE: 
			return 80
		MapRegion.MapRegionType.SHOP: 
			return 60
		MapRegion.MapRegionType.ARENA: 
			return 40
		MapRegion.MapRegionType.DEV_ROOM: 
			return 20
		MapRegion.MapRegionType.START:
			return 10
	return 0 # NORMAL, OPEN_WORLD mają 0

## Funkcja pomocnicza: Kradnie teksturę z drzwi, które postawiłeś ręcznie na scenie
func _get_manual_door_texture(door: Door) -> Texture2D:
	if door.door_texture != null:
		return door.door_texture
		
	var sprite = door.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		return sprite.texture
		
	return null

## Skrypt Hybrydowy do automatycznego parowania drzwi
func _auto_link_doors() -> void:
	for map_region in all_map_regions:
		for door in map_region.doors:
			# 1. HYBRYDA: Jeśli drzwi zostały połączone ręcznie przez Ciebie w Inspektorze, ignorujemy je
			if door.destination_door != null:
				continue
				
			# 2. Sprawdzamy kierunek drzwi
			var offset = door.get_direction_offset()
			if offset == Vector2i.ZERO:
				continue # Jeśli zapomniałeś ustawić kierunek, pomijamy te drzwi
				
			# 3. Szukamy sąsiada na siatce względem naszego obecnego pokoju
			var target_coords = map_region.map_position + offset
			var neighbor_map_region = get_map_region_at(target_coords)
			
			if neighbor_map_region:
				# 4. Szukamy drzwi u sąsiada, które patrzą DOKŁADNIE w naszą stronę (wektor przeciwny)
				var opposite_offset = -offset
				for neighbor_door in neighbor_map_region.doors:
					
					# Jeśli znajdziemy pasujące wolne drzwi...
					if neighbor_door.destination_door == null and neighbor_door.get_direction_offset() == opposite_offset:
						
						# 5. ŁĄCZYMY DRZWI ZE SOBĄ Z OBU STRON!
						door.destination_door = neighbor_door
						neighbor_door.destination_door = door
						
						print("Map: Zszyto automatycznie drzwi między [" + map_region.name + "] a [" + neighbor_map_region.name + "]")
						break

## Pobiera odpowiednią teksturę drzwi na podstawie typu sąsiedniego pokoju
func _get_door_texture_for_map_region_type(type: MapRegion.MapRegionType) -> Texture2D:
	match type:
		MapRegion.MapRegionType.BOSS:
			return preload("res://assets/textures/samples_examples/door/red_door.png")
		MapRegion.MapRegionType.SHOP:
			return preload("res://assets/textures/samples_examples/door/purple_door.png")
		MapRegion.MapRegionType.TREASURE:
			return preload("res://assets/textures/samples_examples/door/orange_door.png")
		MapRegion.MapRegionType.DEV_ROOM:
			return preload("res://assets/textures/samples_examples/door/black_door.png")
		MapRegion.MapRegionType.ARENA:
			return preload("res://assets/textures/samples_examples/door/dark_blue_door.png")
	return null # Zwraca null dla Normalnego, używając domyślnej tekstury
