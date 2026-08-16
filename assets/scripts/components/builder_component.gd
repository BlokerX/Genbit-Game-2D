extends Node
class_name BuilderComponent

@export_category("Builder Settings")
## Rozmiar siatki, do której przyciągany jest obiekt (np. 16 lub 32 piksele). 
## Jeśli ustawisz na 0, obiekt będzie poruszał się płynnie piksel po pikselu.
@export var grid_size: float = 64.0 
## Odległość od gracza, w jakiej pojawia się obiekt, gdy gracz używa pada (zamiast myszki).
@export var build_range: float = 50.0 

# --- ZMIENNE WEWNĘTRZNE SYSTEMU ---
## Przechowuje aktualną scenę (prefab), którą próbujemy postawić (np. skrzynię).
var current_build_scene: PackedScene = null
## Referencja do "ducha" (półprzezroczystego hologramu), który podąża za celownikiem/kursorem.
var ghost_instance: Node2D = null

## Flaga określająca, czy gracz aktualnie znajduje się w trybie budowania.
var is_building: bool = false
## Flaga określająca, czy aktualne miejsce podświetlone przez ducha jest wolne (nie koliduje ze ścianami).
var can_place_here: bool = true

## Przechowuje aktualny obrót obiektu (0, 90, 180, 270)
var current_rotation_degrees: float = 0.0

## Pobiera referencję do rodzica, którym powinien być skrypt gracza (PlayerCharacter).
@onready var player: PlayerCharacter = get_parent()

# Funkcja _process wywołuje się co każdą klatkę gry (np. 60 razy na sekundę).
func _process(_delta: float) -> void:
	# Jeśli nie budujemy lub duch z jakiegoś powodu zniknął, przerywamy działanie.
	if not is_building or not is_instance_valid(ghost_instance):
		return
		
	var target_pos = Vector2.ZERO
	
	# --- 1. OBLICZANIE POZYCJI DUCHA ---
	if player.is_using_mouse:
		# Jeśli gracz używa myszki, duch po prostu leci do kursora.
		target_pos = ghost_instance.get_global_mouse_position()
		
		# --- NOWOŚĆ: Zabezpieczenie promienia budowy również dla myszki ---
		var max_range = player.get_current_attack_range()
		if max_range > 0 and player.global_position.distance_to(target_pos) > max_range:
			var dir = player.global_position.direction_to(target_pos)
			target_pos = player.global_position + (dir * max_range)
	else:
		# Jeśli gracz używa pada, pobieramy pozycję wirtualnego kursora ze skanera!
		if player.aim_controller:
			target_pos = player.aim_controller.virtual_cursor_pos
		else:
			target_pos = player.global_position

	# --- 2. PRZYCIĄGANIE DO ŚRODKA KAFELKA (SNAP TO CENTER) ---
	if grid_size > 0:
		# KROK A: Obliczamy, w którym kafelku (komórce siatki) aktualnie znajduje się nasz cel.
		# Funkcja floor() zaokrągla w dół. Np. pozycja 100 / 64 daje kafelek nr 1.
		var cell_x = floor(target_pos.x / grid_size)
		var cell_y = floor(target_pos.y / grid_size)
		
		# KROK B: Mnożymy numer kafelka przez jego rozmiar (np. 1 * 64 = 64) 
		# i dodajemy połowę kafelka (np. 32), aby ustawić ducha idealnie w jego środku.
		target_pos = Vector2(
			(cell_x * grid_size) + (grid_size / 2.0),
			(cell_y * grid_size) + (grid_size / 2.0)
		)
	
	# Aktualizujemy pozycję naszego ducha na mapie.
	ghost_instance.global_position = target_pos
	
	# Sprawdzamy, czy nowa pozycja ducha z niczym nie koliduje.
	_validate_placement()


## Funkcja wywoływana przez gracza, gdy wciśnie przycisk wejścia w tryb budowy.
func start_building(item_data: PlaceableComponent) -> bool:
	# Sprawdzamy czy przedmiot w ogóle ma przypisaną scenę
	if item_data.scene_path == null or item_data.scene_path.is_empty():
		push_error("BuilderComponent: Przedmiot nie ma przypisanej sceny: ", item_data.item_name)
		return false
	
	# Builder sam ładuje scenę z dysku!
	var loaded_scene = load(item_data.scene_path) as PackedScene
	if not loaded_scene:
		push_error("BuilderComponent: Nie udało się załadować sceny ze ścieżki: ", item_data.scene_path)
		return false

	# Jeśli gracz już coś budował, niszczymy starego ducha dla bezpieczeństwa.
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		
	# Zapisujemy załadowaną scenę i włączamy tryb budowy.
	current_build_scene = loaded_scene
	is_building = true
	
	# Resetujemy obrót do domyślnego przy wyciągnięciu nowego przedmiotu
	current_rotation_degrees = 0.0
	
	# --- NOWOŚĆ: Resetujemy wirtualny kursor pada, żeby budynek zaczął się na postaci ---
	if player.aim_controller:
		player.aim_controller.reset_virtual_cursor()
	
	# Tworzymy instancję ducha ze sceny przedmiotu.
	ghost_instance = current_build_scene.instantiate()
	
	# Aplikujemy zresetowany obrót
	ghost_instance.rotation_degrees = current_rotation_degrees
	
	# BARDZO WAŻNE: Wyłączamy duchowi kolizje fizyczne, żeby nie odpychał gracza.
	_disable_collisions(ghost_instance)
	
	# Dodajemy ducha do głównego drzewa sceny (na mapę).
	get_tree().current_scene.add_child(ghost_instance)
	
	return true # Zwracamy true, bo udało się odpalić tryb budowania!


# --- OBRACANIE ---
func rotate_object() -> void:
	if not is_building or not is_instance_valid(ghost_instance):
		return
		
	# Dodajemy 90 stopni
	current_rotation_degrees += 90.0
	
	# Zapętlamy z powrotem do zera, jeśli zrobimy pełne koło
	if current_rotation_degrees >= 360.0:
		current_rotation_degrees = 0.0
		
	# Aplikujemy nowy obrót do ducha
	ghost_instance.rotation_degrees = current_rotation_degrees
	
	# Ponownie sprawdzamy kolizję (po obrocie obiekt mógł uderzyć w ścianę!)
	_validate_placement()


# Funkcja wywoływana, gdy gracz anuluje budowę lub zmieni broń.
func stop_building() -> void:
	# Usuwamy ducha z mapy, czyścimy zmienne i wyłączamy tryb budowy.
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	ghost_instance = null
	current_build_scene = null
	is_building = false


# Funkcja wywoływana przez gracza (przyciskiem Ataku), by postawić obiekt.
func try_place_object() -> bool:
	# Zwraca TRUE, jeśli udało się postawić, FALSE, jeśli miejsce jest zablokowane.
	if not can_place_here or current_build_scene == null:
		print("BuilderComponent: Miejsce zablokowane!")
		return false
		
	# Skoro miejsce jest wolne, tworzymy WŁAŚCIWY obiekt.
	var final_instance = current_build_scene.instantiate()
	
	# Przekazanie Duszy (ItemInstance)
	if final_instance is PlacedObject:
		var hand_item = player.get_inventory().get_current_item()
		
		var unique_data = hand_item.data.duplicate(true)
		var placed_item_instance = ItemInstance.new(unique_data, 1)
		
		# --- NOWOŚĆ ECS: Klonujemy wytrzymałość ze słownika state, jeśli istniała ---
		if hand_item.state.has("durability"):
			placed_item_instance.state["durability"] = hand_item.state["durability"]
		
		final_instance.set("item_instance", placed_item_instance)
	
	# Kopiujemy obrót z ducha do docelowego obiektu!
	final_instance.rotation_degrees = current_rotation_degrees
	
	# Zamiast wrzucać obiekt byle gdzie, wysyłamy sygnał do gracza/Map.
	player.entity_spawn_requested.emit(final_instance, ghost_instance.global_position)
	print("BuilderComponent: Postawiono obiekt (Obrót: " + str(current_rotation_degrees) + "°)")
	return true


# Wewnętrzna funkcja sprawdzająca kolizje (podświetla na zielono/czerwono).
func _validate_placement() -> void:
	can_place_here = true
	var is_blocked = false
	var area = ghost_instance.get_node_or_null("BuildArea")
	
	if area and area is Area2D:
		var col_shape = area.get_node_or_null("CollisionShape2D")
		if col_shape and col_shape.shape:
			# NATYCHMIASTOWE ZAPYTANIE DO SILNIKA FIZYKI
			var space_state = ghost_instance.get_world_2d().direct_space_state
			var query = PhysicsShapeQueryParameters2D.new()
			query.shape = col_shape.shape
			query.transform = col_shape.global_transform
			query.collision_mask = area.collision_mask
			query.collide_with_bodies = true
			query.collide_with_areas = true # Sprawdzamy też obszary innych budynków
			
			var results = space_state.intersect_shape(query)
			
			for res in results:
				var collider = res.collider
				
				# --- WSPINACZKA PO DRZEWIE ---
				# Sprawdzamy, czy uderzyliśmy w sam obiekt, czy w jakieś jego dziecko (np. Area2D)
				var current_node = collider
				var should_ignore = false
				
				while current_node != null:
					# Ignorujemy samego ducha i przedmioty leżące na ziemi
					if current_node == ghost_instance or current_node is ItemPickup:
						should_ignore = true
						break
					current_node = current_node.get_parent()
					
				if should_ignore:
					continue
				# -----------------------------
					
				# Jeśli dotarliśmy tutaj, to trafiliśmy na inną ścianę, wroga lub skrzynię - BLOKUJEMY
				is_blocked = true
				break
		else:
			# Fallback, jeśli nie ma CollisionShape2D
			for body in area.get_overlapping_bodies():
				var current_node = body
				var should_ignore = false
				
				while current_node != null:
					if current_node == ghost_instance or current_node is ItemPickup:
						should_ignore = true
						break
					current_node = current_node.get_parent()
					
				if not should_ignore:
					is_blocked = true
					break

	if is_blocked:
		can_place_here = false
		_update_ghost_color(Color(1.0, 0.0, 0.0, 0.75)) # Czerwony - Zablokowane
	else:
		can_place_here = true
		_update_ghost_color(Color(0.0, 1.0, 0.0, 0.75)) # Zielony - Wolne

func _update_ghost_color(color: Color) -> void:
	if "modulate" in ghost_instance:
		ghost_instance.modulate = color

func _disable_collisions(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		var parent = node.get_parent()
		if parent == null or parent.name != "BuildArea":
			node.disabled = true
	for child in node.get_children():
		_disable_collisions(child)
	
	# przypadek interactable_component
	var interactable = node.get_node_or_null("InteractableComponent")
	if interactable:
		# Metoda 1: Wyłączenie całego węzła (najpewniejsza)
		interactable.process_mode = Node.PROCESS_MODE_DISABLED
