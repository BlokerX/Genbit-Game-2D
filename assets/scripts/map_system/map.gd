extends Node2D
## Klasa poziomu, przechowywująca pokoje na poziomie
class_name Map

# --- STAŁE (Wyeliminowanie magicznych stringów) ---
## Grupa gracza
const PLAYER_GROUP = "Player"
const MapLightingControllerType = preload(
	"res://assets/scripts/map_system/map_lighting_controller.gd"
)
const MapDoorGeneratorType = preload(
	"res://assets/scripts/map_system/map_door_generator.gd"
)
const MapRegionEntryControllerType = preload(
	"res://assets/scripts/map_system/map_region_entry_controller.gd"
)

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
var _lighting_controller: MapLightingControllerType
var _door_generator: MapDoorGeneratorType
var _region_entry_controller: MapRegionEntryControllerType
var _is_transitioning: bool = false

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
	_lighting_controller = MapLightingControllerType.new()
	_lighting_controller.initialize(global_darkness)
	_door_generator = MapDoorGeneratorType.new()
	_door_generator.configure(auto_door_scene, default_map_door_texture)
	_region_entry_controller = MapRegionEntryControllerType.new()
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
		if not map_region_to_load.is_inside_tree():
			add_child(map_region_to_load)
		_lighting_controller.apply_region(map_region_to_load)
		
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

func is_transition_active() -> bool:
	return _is_transitioning or TransitionManager.is_transition_active()

## Funkcja zmiany pokoju
func change_map_region(new_map_region: MapRegion, target_door: Node2D = null, force_teleport: bool = false) -> void:
	if new_map_region == null:
		push_error("Map: Nie można przejść do pustego pokoju.")
		return
	if is_transition_active():
		return
	_is_transitioning = true

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
		if not is_inside_tree():
			_finish_transition(player)
			return
	
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

	if not do_slide:
		_lighting_controller.apply_region(current_map_region)
		
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
		_region_entry_controller.place_player_in_region(
			player,
			current_map_region,
			target_door,
			force_teleport,
			_on_entity_spawn_requested
		)
		
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
		if not is_inside_tree():
			return
		
	if do_slide:
		# ANIMACJA PRZESUWANIA (TWEEN)
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var anim_duration = 0.45
		
		tween.tween_property(current_map_region, "position", Vector2.ZERO, anim_duration)
		if old_map_region and not is_same_map_region:
			tween.tween_property(old_map_region, "position", -slide_vector, anim_duration)
			
		_lighting_controller.add_transition_tweens(
			tween,
			old_map_region,
			current_map_region,
			anim_duration
		)
			
		await tween.finished
		if not is_inside_tree():
			_finish_transition(player)
			return
		
		# Sprzątanie starego pokoju PO ANIMACJI
		if old_map_region and not is_same_map_region:
			old_map_region.process_mode = Node.PROCESS_MODE_INHERIT # Przywracamy fizykę dla historii odwiedzonych
			_disconnect_door_signals(old_map_region)
			if old_map_region.is_inside_tree():
				remove_child(old_map_region)
			old_map_region.position = Vector2.ZERO 
			
	else:
		# Jeśli TYLKO FADE, stary pokój zniknął wyżej, zostaje tylko rozjaśnić obraz
		if do_fade:
			TransitionManager.fade_to_normal()
			await TransitionManager.on_fade_in_finished
			if not is_inside_tree():
				_finish_transition(player)
				return

	_finish_transition(player)

func _finish_transition(player: PlayerCharacter) -> void:
	_is_transitioning = false
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
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
func handle_player_respawn(_player: PlayerCharacter) -> void:
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
	_door_generator.spawn_missing_doors(map_region_grid)

## Skrypt Hybrydowy do automatycznego parowania drzwi
func _auto_link_doors() -> void:
	_door_generator.link_doors(all_map_regions, map_region_grid)
