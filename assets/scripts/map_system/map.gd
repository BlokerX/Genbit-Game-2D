extends Node2D
## Klasa poziomu, przechowywująca pokoje na poziomie
class_name Map

# --- STAŁE (Wyeliminowanie magicznych stringów) ---
## Grupa gracza
const PLAYER_GROUP = "Player"

## Sygnał zmiany pokoju
signal room_changed(new_room: Room)

## Sygnał aktualizacji mapy (UI)
signal map_updated()

@export_group("Ustawienia zapisu (Czy level jest zapamiętywany po wyjściu)")
## Jeśli TRUE: Pokoje wewnątrz tego poziomu będą zarządzane przez SaveManagera.
## Zabite potwory, zniszczone skrzynie i upuszczony loot ZOSTANĄ NA ZAWSZE w pliku save'a.
## Jeśli FALSE: To jest "Dungeon". Wszystko wraca do normy po wyjściu z mapy.
@export var is_persistent_level: bool = true

@export_group("Główne Obiekty")
## Pokój startowy
@export var starting_room: Room


@export_group("Ustawienia Respawnu")
## Czy po respawnie wyczyścić historię odkrytych i odwiedzonych pokoi na minimapie?
@export var reset_map_history_on_respawn: bool = true

## Czy całkowicie zresetować poziom (przeładować aktualną scenę gry)?
## UWAGA: Przeładowanie sceny zresetuje też statystyki/ekwipunek gracza do wartości początkowych.
@export var reload_entire_scene_on_respawn: bool = false

## Wewnętrzna zmienna systemowa: Gwarantuje, że RAM wie, skąd wzięła się ta mapa.
## (Nie zmieniaj tego ręcznie!)
var source_level_path: String = ""

## Obecny pokój na scenie
var current_room: Room
## Wszystkie pokoje
var all_rooms: Array[Room] = []
## Odkryte pokoje (widoczne na mapie)
var discovered_rooms: Array[Room] = []
## Pokoje odwiedzone
var visited_rooms: Array[Room] = []

# Słownik przestrzenny (Grid)
## Kluczem jest Vector2i (np. Vector2i(0,0)), a wartością obiekt Room
var room_grid: Dictionary = {}

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
		if child is Room:
			register_room(child)
			# Ukrywamy wszystko oprócz pokoju startowego, by nie obciążać silnika
			if child != starting_room:
				remove_child(child)
	
	# 1. NAJPIERW z centralnego poziomu spawnujemy fizyczne drzwi tam, gdzie oba pokoje się zgadzają
	_auto_spawn_missing_doors()
	# 2. POTEM Auto-Linker zszywa wszystkie drzwi (te wstawione ręcznie i te wstawione przez automat)
	_auto_link_doors()
	
	initialize_level()

func initialize_level() -> void:
	# --- SYSTEM ODBIERANIA GRACZA Z INNEGO POZIOMU ---
	var room_to_load: Room = starting_room
	var spawn_node: Node2D = null
	
	# Sprawdzamy, czy w GlobalLevelManagerze jest zapisany cel podróży
	if GlobalLevelManager.target_entrance_id != "":
		var entrance = _find_entrance_by_id(GlobalLevelManager.target_entrance_id)
		if entrance:
			# Znaleźliśmy nasze wejście! Szukamy, w którym pokoju ono leży.
			room_to_load = _get_room_of_node(entrance)
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
	
	# Ładujemy ustalony pokój i WWRZUCAMY do niego wyjętego wcześniej gracza
	if room_to_load:
		# Ustawiamy natychmiastowy kolor mroku dla pierwszego pokoju
		global_darkness.color = room_to_load.darkness_color if room_to_load.is_dark_room else Color.WHITE
		
		if not room_to_load.is_inside_tree():
			add_child(room_to_load)
		
		# Wywołujemy change_room. Nasza funkcja w map.gd automatycznie 
		# znajdzie gracza (nawet jeśli był tymczasowo w root) i wsadzi go do "Entities"!
		call_deferred("change_room", room_to_load, spawn_node)
		
		# Rozjaśniamy ekran na nowej mapie!
		TransitionManager.fade_to_normal(0.4)

## Funkcja pomocnicza: Szuka po ID wejścia na całej mapie
func _find_entrance_by_id(id: String) -> LevelEntrance:
	for room in all_rooms:
		# Przeszukujemy dzieci pokoju w poszukiwaniu klasy LevelEntrance
		for child in room.find_children("*", "LevelEntrance", true, false):
			if child.my_entrance_id == id:
				return child as LevelEntrance
	return null

## Funkcja pomocnicza: Zwraca pokój, do którego należy dany węzeł
func _get_room_of_node(node: Node) -> Room:
	var current = node
	while current != null:
		if current is Room:
			return current
		current = current.get_parent()
	return null

# --- FUNKCJE DYNAMIKI MAPY ---

## Rejestracja pokoju, przypisuje go do list pokoi i aktualizuje mapę
func register_room(room: Room) -> void:
	if not all_rooms.has(room):
		all_rooms.append(room)
		
		# Zapisujemy pokój w siatce (Grid)
		# Używamy zmiennej map_position z room.gd jako klucza
		room_grid[room.map_position] = room
		
		map_updated.emit()

## Funkcja do dynamicznego usuwania pokoju (np. pokój się zapadł/zniszczył)
func unregister_room(room: Room) -> void:
	if all_rooms.has(room):
		all_rooms.append(room)
		all_rooms.erase(room)
	
	if discovered_rooms.has(room):
		discovered_rooms.erase(room)
		
	# Usunięcie z listy odwiedzonych przy kasowaniu pokoju
	if visited_rooms.has(room):
		visited_rooms.erase(room)
	
	# Usuwamy pokój z siatki
	if room_grid.has(room.map_position) and room_grid[room.map_position] == room:
		room_grid.erase(room.map_position)
	
	map_updated.emit() # Informujemy UI o zmianie

## Odwiedzenie pokoju (dodaje do listy odwiedzonych)
func discover_room(room: Room) -> void:
	if not discovered_rooms.has(room):
		discovered_rooms.append(room)
		map_updated.emit() # Odświeżamy mapę po odkryciu

## Zwraca pokój w którym znajdują się drzwi
func find_room_by_door(target_door: Door) -> Room:
	for room in all_rooms:
		# Sprawdzamy czy te konkretne drzwi należą do tego pokoju
		# Nawet jeśli pokój jest poza drzewem sceny, ta funkcja zadziała
		if room.is_ancestor_of(target_door):
			return room
	return null

## Odkrywa wszystkie pokoje sąsiadujące z podanym pokojem (poprzez połączone drzwi)
func _discover_neighboring_rooms(room: Room) -> void:
	for door in room.doors:
		if door.destination_door:
			# Szukamy pokoju, w którym znajdują się drzwi docelowe
			var neighbor_room = find_room_by_door(door.destination_door)
			# Sprawdzamy, czy pokój istnieje i CZY NIE JEST oznaczony jako sekretny
			if neighbor_room and not neighbor_room.is_secret:
				discover_room(neighbor_room) # Odkrywamy go na mapie

## Funkcja zmiany pokoju
func change_room(new_room: Room, target_door: Node2D = null) -> void:
	# 1. NAJPIERW ŁAPIEMY GRACZA! Zanim cokolwiek usuniemy.
	var player = get_player()
	
	var old_room = current_room
	# Zabezpieczenie przed usuwaniem pokoju, w którym już jesteśmy (Respawn)
	var is_same_room = (old_room == new_room)
	
	# ODCZYTANIE TRYBU Z NOWEGO POKOJU (Zabezpieczenie: FADE jako domyślny)
	var mode = new_room.transition_mode if "transition_mode" in new_room else 0
	var do_fade = (mode == 0 or mode == 2) # FADE lub BOTH
	var do_slide = (mode == 1 or mode == 2) # SLIDE lub BOTH
	
	# --- Zabezpieczenie pierwszego pokoju (Start Gry / Miękki Respawn) ---
	if old_room == null or is_same_room:
		do_slide = false # Wymuszamy brak przesuwania na starcie i przy respawnie
	
	# ZAMROŻENIE GRACZA NA CZAS ZMIANY
	if player:
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)
		# WYŁĄCZENIE FIZYKI GRACZA (żeby ściany go nie wyrzuciły przy przesuwaniu!)
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Wyłączamy fizykę tylko jeśli faktycznie opuszczamy stary pokój
	if old_room and not is_same_room:
		old_room.process_mode = Node.PROCESS_MODE_DISABLED

	# ŚCIEMNIENIE EKRANU
	if do_fade:
		TransitionManager.fade_to_black(0.2)
		await TransitionManager.on_fade_out_finished
	
	# --- TUTAJ GRA JEST CAŁKOWICIE ZAKRYTA CZERNIĄ LUB GOTOWA DO PRZESUNIĘCIA ---
	current_room = new_room
	
	# Ściągamy efekty środowiskowe starego pokoju z gracza (TYLKO AURĘ!)
	if old_room and player:
		for effect in old_room.ambient_aura_effects:
			if effect != null:
				player.remove_effect_by_name(effect.effect_name)
	
	# Zabezpieczamy gracza: wyciągamy go ze starego pokoju
	if player and player.get_parent():
		player.get_parent().remove_child(player)

	# 2. OBLICZANIE WEKTORA PRZESUNIĘCIA (Jeśli to tryb SLIDE/BOTH)
	var slide_vector = Vector2.ZERO
	if do_slide and target_door and old_room and not is_same_room:
		if target_door is Door:
			var dir_offset = target_door.get_direction_offset()
			slide_vector = Vector2(-dir_offset.x * current_room.size_px.x, -dir_offset.y * current_room.size_px.y)

	# 3. Dodajemy nowy pokój do sceny
	current_room.position = slide_vector # Ustawia offset jeśli SLIDE, inaczej Vector2.ZERO
	current_room.visible = true
	
	if not current_room.is_inside_tree():
		add_child(current_room)
		
	# Usuwamy stary pokój tylko jeśli to był INNY pokój
	if not do_slide and old_room and not is_same_room:
		old_room.process_mode = Node.PROCESS_MODE_INHERIT
		_disconnect_door_signals(old_room)
		if old_room.is_inside_tree():
			remove_child(old_room)
		
	_connect_door_signals(current_room)
	discover_room(current_room)
	_discover_neighboring_rooms(current_room)
	
	if not visited_rooms.has(current_room):
		visited_rooms.append(current_room)
	
	room_changed.emit(current_room)
	
	# 4. UMIESZCZAMY GRACZA W NOWYM POKOJU
	if player:
		if not player.entity_spawn_requested.is_connected(_on_entity_spawn_requested):
			player.entity_spawn_requested.connect(_on_entity_spawn_requested)
		
		# Szukamy węzła Y-Sort i dodajemy gracza
		var target_parent = current_room.find_child("Entities")
		if not target_parent:
			target_parent = current_room
		target_parent.add_child(player)
		
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
			if current_room.spawn_points.size() > 0:
				player.global_position = current_room.spawn_points[0].global_position
			else:
				player.global_position = current_room.global_position + (current_room.size_px / 2.0)
		# ------------------------------------------------------------------------
		
		# Nakładamy nowe efekty typu AURA (nieskończone)
		for effect in current_room.ambient_aura_effects:
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
		for effect in current_room.sticky_entry_effects:
			if effect != null:
				var normal_effect = effect.duplicate()
				# Klątwy z pułapek normalnie nałożymy przez receive_effect, 
				# aby gracz MÓGŁ wyleczyć je np. antidotum po wybiegnięciu z pokoju.
				player.receive_effect(normal_effect)
		
	# 5. Odpalamy logikę walki / blokady pokoju
	current_room.check_and_lock_room()
	
	# 6. Informujemy gracza o strefie pacyfizmu
	if player and "is_in_pacifist_zone" in player:
		player.is_in_pacifist_zone = current_room.pacifist_zone
	
	# --- 7. FAZA ANIMACJI, ROZJAŚNIANIA I ŚWIATEŁ ---
	
	# Jeśli BOTH, zaczynamy rozjaśniać w tle w trakcie przesuwania
	if do_fade and do_slide:
		TransitionManager.fade_to_normal(0.2)
		
	if do_slide:
		# ANIMACJA PRZESUWANIA (TWEEN)
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var anim_duration = 0.45
		
		tween.tween_property(current_room, "position", Vector2.ZERO, anim_duration)
		if old_room and not is_same_room:
			tween.tween_property(old_room, "position", -slide_vector, anim_duration)
			
		# --- SYSTEM PŁYNNEGO PRZEJŚCIA ŚWIATEŁ ---
		# 1. Płynna zmiana mroku całej planszy
		var target_color = current_room.darkness_color if current_room.is_dark_room else Color.WHITE
		tween.tween_property(global_darkness, "color", target_color, anim_duration)
		
		# 2. Wygaszamy starą latarkę, żeby nie świeciła do nowego pokoju
		if old_room and not is_same_room:
			var old_light = old_room.find_child("CenterRoomLight", false, false)
			if old_light and old_light is PointLight2D:
				tween.tween_property(old_light, "energy", 0.0, anim_duration)
				
		# 3. Płynnie zapalamy nową latarkę
		var new_light = current_room.find_child("CenterRoomLight", false, false)
		if new_light and new_light is PointLight2D:
			new_light.energy = 0.0 # Zaczynamy od zgaszonej
			tween.tween_property(new_light, "energy", current_room.center_light_energy, anim_duration)
		# -----------------------------------------
			
		await tween.finished
		
		# Sprzątanie starego pokoju PO ANIMACJI
		if old_room and not is_same_room:
			old_room.process_mode = Node.PROCESS_MODE_INHERIT # Przywracamy fizykę dla historii odwiedzonych
			_disconnect_door_signals(old_room)
			if old_room.is_inside_tree():
				remove_child(old_room)
			old_room.position = Vector2.ZERO 
			
	else:
		# Jeśli TYLKO FADE, stary pokój zniknął wyżej, zostaje tylko rozjaśnić obraz
		var target_color = current_room.darkness_color if current_room.is_dark_room else Color.WHITE
		global_darkness.color = target_color
		
		if do_fade:
			TransitionManager.fade_to_normal(0.2)
			await TransitionManager.on_fade_in_finished

	# 8. ODMROŻENIE GRACZA (Przywrócenie fizyki po wszystkich animacjach!)
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		if player.has_method("set_physics_process"):
			player.set_physics_process(true)

## Obsługa spawnowania gracza z sygnału
func _on_entity_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	# --- NAPRAWA KRYTYCZNA: Tarcza obronna ---
	# Jeśli mapa jest "uśpiona" w RAM-ie i nie ma jej na ekranie, absolutnie ignoruje żądania spawnu!
	if not is_inside_tree():
		return
	
	if current_room:
		current_room.add_child(spawned_node)
	else:
		# Awaryjne dodanie bezpośrednio do sceny, jeśli nie ma aktywnego pokoju
		get_tree().current_scene.add_child(spawned_node)
		
	# Pozycję ustalamy ZAWSZE po dodaniu obiektu do drzewa!
	spawned_node.global_position = spawn_pos

## Podłączenie sygnału do drzwi
func _connect_door_signals(room: Room) -> void:
	# Room sam pobiera swoje drzwi w _ready lub auto_fetch
	for door in room.doors:
		if not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

## Odłączenie sygnału od drzwi
func _disconnect_door_signals(room: Room) -> void:
	for door in room.doors:
		if door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

## Obługa sygnału wejścia w drzwi
func _on_door_entered(door: Door) -> void:
	# Sprawdzamy, czy te drzwi w ogóle gdzieś prowadzą
	if door.destination_door:
		# Używamy naszej nowej funkcji przeszukującej listę all_rooms
		var next_room = find_room_by_door(door.destination_door)
		
		if next_room:
			call_deferred("change_room", next_room, door.destination_door)
		else:
			push_warning("Map: Drzwi docelowe nie znajdują się w żadnym węźle Room!")
	else:
		push_warning("Map: Gracz wszedł w drzwi, ale nie przypisano im destination_door w edytorze.")

## Funkcja wywoływana, gdy gracz zostanie zrespawnowany
func handle_player_respawn(player: PlayerCharacter) -> void:
	print("Menedżer Mapy: Gracz zainicjował respawn...")
	
	if starting_room:
		# Czyścimy wszystkie negatywne efekty (jak przy przechodzeniu levelu)
		if player.has_method("clear_all_effects"):
			player.clear_all_effects()
			
		# Jeśli mapa jest stała, wczytujemy ją z pliku do czystego stanu
		# (z pominięciem przedmiotów "usuniętych trwale") - przygotowanie do Serializacji!
		if is_persistent_level:
			print("Menedżer Mapy: Reset trwałej mapy. Oczekuję na mechanikę SaveManager'a...")
			# W przyszłości: SaveManager.reload_map_from_disk(self)
		else:
			print("Menedżer Mapy: Miękki reset (odtworzenie proceduralnych zasobów pokoju).")
			
		# Zdejmujemy ewentualne zaciemnienie po śmierci
		TransitionManager.fade_to_black(0.0) # Usuwa alfę
		
		# Przenosimy gracza z powrotem do pokoju startowego 
		change_room(starting_room)
		
		if starting_room.spawn_points.size() > 0:
			player.global_position = starting_room.spawn_points[0].global_position
		else:
			var room_center_offset = starting_room.size_px / 2.0
			player.global_position = starting_room.global_position + room_center_offset

		# Obsługa flagi historii mapy
		if reset_map_history_on_respawn:
			discovered_rooms.clear()
			visited_rooms.clear()
			discover_room(starting_room)
		else:
			discover_room(starting_room)
			
		map_updated.emit()
	else:
		# Fallback - awaryjnie w ostateczności
		push_error("Menedżer Mapy: Brak 'starting_room'. Twardy reset sceny.")
		get_tree().reload_current_scene()

## Zwrócenie gracza ze sceny
func get_player() -> PlayerCharacter :
	return get_tree().get_first_node_in_group(PLAYER_GROUP)

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
		for room in all_rooms:
			if is_instance_valid(room) and room.get_parent() == null:
				room.queue_free()

## Funkcja do sprawdzania co leży na danym polu
## Zwraca pokój znajdujący się na podanych koordynatach siatki (lub null, jeśli pole jest puste)
func get_room_at(coords: Vector2i) -> Room:
	if room_grid.has(coords):
		return room_grid[coords]
	return null

## Centralny system generowania drzwi. 
func _auto_spawn_missing_doors() -> void:
	if auto_door_scene == null:
		return
	
	# Przeszukujemy każdy pokój na wirtualnej siatce
	for coords in room_grid.keys():
		var grid_room = room_grid[coords]
		
		# KRAWĘDŹ 1: Sprawdzamy sąsiada po PRAWEJ (X+1, Y)
		var right_coords = coords + Vector2i(1, 0)
		if room_grid.has(right_coords):
			var right_room = room_grid[right_coords]
			if grid_room.allow_door_right and right_room.allow_door_left:
				_sync_door_pair(grid_room, Door.Direction.RIGHT, right_room, Door.Direction.LEFT)
				
		# KRAWĘDŹ 2: Sprawdzamy sąsiada W DÓŁ (X, Y+1)
		var down_coords = coords + Vector2i(0, 1)
		if room_grid.has(down_coords):
			var down_room = room_grid[down_coords]
			if grid_room.allow_door_down and down_room.allow_door_up:
				_sync_door_pair(grid_room, Door.Direction.DOWN, down_room, Door.Direction.UP)


## Inteligentne parowanie drzwi - obie strony przejścia ZAWSZE wyglądają identycznie!
func _sync_door_pair(room_a: Room, dir_a: Door.Direction, room_b: Room, dir_b: Door.Direction) -> void:
	var door_a = room_a.get_door(dir_a)
	var door_b = room_b.get_door(dir_b)
	
	# PRIORYTET 1: Oba pokoje mają już Twoje ręczne drzwi. Automat nic nie robi.
	if door_a != null and door_b != null:
		return
		
	# PRIORYTET 2, 3 i 4: Nie ma żadnych ręcznych drzwi - pełen automat.
	if door_a == null and door_b == null:
		# --- KLUCZ: Wyliczamy jedną, najsilniejszą teksturę dla OBU pokoi naraz! ---
		var best_tex = _get_best_door_texture(room_a, room_b)
		
		# Tworzymy i wstawiamy drzwi z tą samą teksturą po obu stronach ściany
		door_a = room_a.spawn_auto_door(dir_a, auto_door_scene, best_tex)
		door_b = room_b.spawn_auto_door(dir_b, auto_door_scene, best_tex)
		return 
		
	# PRIORYTET 1 (dziedziczenie): TYLKO Pokój A ma ręczne drzwi. Pokój B musi je skopiować.
	if door_a != null and door_b == null:
		var tex_b = _get_manual_door_texture(door_a)
		door_b = room_b.spawn_auto_door(dir_b, auto_door_scene, tex_b)
		
	# PRIORYTET 1 (dziedziczenie): TYLKO Pokój B ma ręczne drzwi. Pokój A musi je skopiować.
	elif door_b != null and door_a == null:
		var tex_a = _get_manual_door_texture(door_b)
		door_a = room_a.spawn_auto_door(dir_a, auto_door_scene, tex_a)

## Funkcja pomocnicza: Wylicza "najsilniejszą" teksturę dla całego połączenia
func _get_best_door_texture(room_1: Room, room_2: Room) -> Texture2D:
	# Priorytet 2: Niestandardowy obrazek z Inspektora (jeśli oba mają, wygrywa ten z lewej/góry)
	if room_1.custom_door_texture != null:
		return room_1.custom_door_texture
	if room_2.custom_door_texture != null:
		return room_2.custom_door_texture
		
	# Priorytet 3: Typ pokoju - WALKA NA PUNKTY WAŻNOŚCI
	var weight_1 = _get_room_type_weight(room_1.room_type)
	var weight_2 = _get_room_type_weight(room_2.room_type)
	
	# Jeśli chociaż jeden pokój jest "specjalny" (waga > 0)
	if weight_1 > 0 or weight_2 > 0:
		# Zwycięża ten, który ma więcej punktów!
		if weight_1 >= weight_2:
			return _get_door_texture_for_room_type(room_1.room_type)
		else:
			return _get_door_texture_for_room_type(room_2.room_type)
		
	# Priorytet 4: Domyślna tekstura dla Całej Mapy
	if default_map_door_texture != null:
		return default_map_door_texture
		
	# Priorytet 5: Absolutny domyślny wygląd
	return null

## Funkcja pomocnicza: Ustala, który typ pokoju jest "ważniejszy" przy zderzeniu
func _get_room_type_weight(type: Room.RoomType) -> int:
	match type:
		Room.RoomType.BOSS: 
			return 100 # Boss zawsze dominuje korytarz
		Room.RoomType.TREASURE: 
			return 80
		Room.RoomType.SHOP: 
			return 60
		Room.RoomType.ARENA: 
			return 40
		Room.RoomType.DEV_ROOM: 
			return 20
		Room.RoomType.START:
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
	for room in all_rooms:
		for door in room.doors:
			# 1. HYBRYDA: Jeśli drzwi zostały połączone ręcznie przez Ciebie w Inspektorze, ignorujemy je
			if door.destination_door != null:
				continue
				
			# 2. Sprawdzamy kierunek drzwi
			var offset = door.get_direction_offset()
			if offset == Vector2i.ZERO:
				continue # Jeśli zapomniałeś ustawić kierunek, pomijamy te drzwi
				
			# 3. Szukamy sąsiada na siatce względem naszego obecnego pokoju
			var target_coords = room.map_position + offset
			var neighbor_room = get_room_at(target_coords)
			
			if neighbor_room:
				# 4. Szukamy drzwi u sąsiada, które patrzą DOKŁADNIE w naszą stronę (wektor przeciwny)
				var opposite_offset = -offset
				for neighbor_door in neighbor_room.doors:
					
					# Jeśli znajdziemy pasujące wolne drzwi...
					if neighbor_door.destination_door == null and neighbor_door.get_direction_offset() == opposite_offset:
						
						# 5. ŁĄCZYMY DRZWI ZE SOBĄ Z OBU STRON!
						door.destination_door = neighbor_door
						neighbor_door.destination_door = door
						
						print("Map: Zszyto automatycznie drzwi między [" + room.name + "] a [" + neighbor_room.name + "]")
						break

## Pobiera odpowiednią teksturę drzwi na podstawie typu sąsiedniego pokoju
func _get_door_texture_for_room_type(type: Room.RoomType) -> Texture2D:
	match type:
		Room.RoomType.BOSS:
			return preload("res://assets/textures/samples_examples/door/red_door.png")
		Room.RoomType.SHOP:
			return preload("res://assets/textures/samples_examples/door/purple_door.png")
		Room.RoomType.TREASURE:
			return preload("res://assets/textures/samples_examples/door/orange_door.png")
		Room.RoomType.DEV_ROOM:
			return preload("res://assets/textures/samples_examples/door/black_door.png")
		Room.RoomType.ARENA:
			return preload("res://assets/textures/samples_examples/door/dark_blue_door.png")
	return null # Zwraca null dla Normalnego, używając domyślnej tekstury
