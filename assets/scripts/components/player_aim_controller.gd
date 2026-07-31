extends Node2D
class_name PlayerAimController

## Przenosimy referencję do skanera (teraz jest bezpośrednim dzieckiem tego węzła)
@onready var aim_scanner: RayCast2D = $AimScanner

## Zasięg celownika (tylko interakcje nieposiadające ograniczonego dystansu)
@export var aim_distance: float = 4000.0

## Maksymalny dystans do interakcji z obiektami (np. podnoszenie przedmiotów)
@export var interaction_distance: float = 150.0

## Czy system ma automatycznie zrzucać focus z przedmiotów na wrogów (Pad/Klawiatura)?
@export var auto_enemy_selector: bool = true
## Czy system ma automatycznie namierzać najbliższego wroga i pamiętać ostatniego? (Priorytet dla walki na padzie/klawiaturze)
@export var auto_lock_closest_enemy: bool = true
## Czy celownik ma być aktywny cały czas (True), czy tylko podczas wychylania gałki/strzałek (False)?
@export var continuous_gamepad_aiming: bool = false
## Czy myszka ma trzymać cel dopóki z niego nie odejdziemy (True), czy odznaczać go od razu po zjechaniu kursorem w pustą przestrzeń (False)?
@export var sticky_mouse_aiming: bool = false

# --- NAPRAWA BŁĘDÓW KRYTYCZNYCH ---
## Maska kolizji dla ścian. Ustaw w Inspektorze warstwy (Layers), na których są Twoje ściany/przeszkody!
@export_flags_2d_physics var obstacles_mask: int = 1

# --- ZMIENNE WIRTUALNEGO KURSORA (PAD) ---
var virtual_cursor_pos: Vector2 = Vector2.ZERO
@export var virtual_cursor_speed: float = 450.0
# ------------------------------------------------

## Lokalna pamięć wrogów w pobliżu. Oszczędza 99% zużycia procesora!
var nearby_enemies: Array[Node2D] = []

## Przechowujemy aktualnie namierzony obiekt przez celownik
var current_target: InteractableComponent = null
## Pamięta ostatni cel, który zgubiliśmy tylko przez to, że wybiegliśmy z zasięgu
var last_target: InteractableComponent = null

func _ready() -> void:
	# Tworzymy automatyczny skaner wrogów
	var detection_area = Area2D.new()
	detection_area.collision_layer = 0
	detection_area.collision_mask = 0xFFFFFFFF # Reaguje na wszystkie obiekty
	
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = aim_distance # Zasięg skanera równy max zasięgowi celowania
	collision_shape.shape = circle
	
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	detection_area.body_entered.connect(_on_enemy_entered)
	detection_area.body_exited.connect(_on_enemy_exited)
	
	# Reset kursora na starcie
	reset_virtual_cursor()

func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy") and not nearby_enemies.has(body):
		nearby_enemies.append(body)

func _on_enemy_exited(body: Node2D) -> void:
	if nearby_enemies.has(body):
		nearby_enemies.erase(body)

#region System celowania

## Funkcja resetująca pozycję kursora na graczu ---
func reset_virtual_cursor() -> void:
	virtual_cursor_pos = global_position

# ==========================================
# GŁÓWNY SYSTEM CELOWANIA
# ==========================================

## Główna obsługa celowania
func process_aiming(is_using_mouse: bool, current_attack_range: float):
	# Logika, która decyduje co wywołać
	if is_using_mouse:
		handle_mouse_aiming(current_attack_range)
	else:
		handle_gamepad_aiming(current_attack_range)

## --- CELOWANIE MYSZKĄ ---
func handle_mouse_aiming(current_attack_range : float):
	# 1. Ustawienie pozycji lasera za myszką
	var local_mouse_pos = get_local_mouse_position()
	aim_scanner.target_position = local_mouse_pos.limit_length(aim_distance)
	
	# 2. Aktualizacja Raycastu
	aim_scanner.force_raycast_update()
	var found_target = _get_raycast_target()
	
	# 3. Zabezpieczenie fizyczne dystansu
	found_target = _enforce_distance_check(found_target, current_attack_range)
	
	# 4. Zarządzanie podświetlaniem celu (dla myszki is_gamepad = false)
	_manage_target_highlight(found_target, false, current_attack_range)

## --- CELOWANIE PADEM / KLAWIATURĄ ---
func handle_gamepad_aiming(current_attack_range: float):
	var final_aim_dir = Vector2.ZERO
	var is_pad_aiming = false 
	
	# --- 1. AKTUALIZACJA WIRTUALNEGO KURSORA ---
	var aim_vector = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	
	if aim_vector != Vector2.ZERO:
		is_pad_aiming = true
		# Pobieramy deltę dla płynnego ruchu
		var delta = get_physics_process_delta_time()
		virtual_cursor_pos += aim_vector.normalized() * virtual_cursor_speed * delta
		
		var raw_aim_dir = aim_vector.normalized()
		final_aim_dir = raw_aim_dir
		
		# Magnetyzm celownika dla strzelania
		if current_target != null and is_instance_valid(current_target):
			var target_parent = current_target.get_parent()
			if target_parent != null:
				var dir_to_target = global_position.direction_to(target_parent.global_position)
				if abs(raw_aim_dir.angle_to(dir_to_target)) < 0.8: 
					final_aim_dir = dir_to_target
					
		aim_scanner.target_position = final_aim_dir * aim_distance
	else:
		if not continuous_gamepad_aiming:
			aim_scanner.target_position = Vector2.ZERO

	# --- SMYCZ WIRTUALNEGO KURSORA (Zabezpieczenie przed ucieczką) ---
	var limit_range = current_attack_range if current_attack_range > 0 else aim_distance
	if global_position.distance_to(virtual_cursor_pos) > limit_range:
		var dir_to_cursor = global_position.direction_to(virtual_cursor_pos)
		# Zabezpieczenie przed błędem matematycznym gdy gracz i kursor są w tym samym miejscu
		if dir_to_cursor == Vector2.ZERO: 
			dir_to_cursor = Vector2.DOWN
		virtual_cursor_pos = global_position + (dir_to_cursor * limit_range)
	# -----------------------------------------------------------------

	# 2. Aktualizacja Raycastu
	aim_scanner.force_raycast_update()
	var found_target = _get_raycast_target()
	var found_is_enemy = false
	
	if found_target != null:
		var tp = found_target.get_parent()
		if tp and tp.is_in_group("Enemy"):
			found_is_enemy = true

	# --- SYSTEM PAMIĘCI I AUTO-CELOWANIA WROGÓW ---
	if auto_lock_closest_enemy and not found_is_enemy:
		var best_enemy = null
		var best_dist = current_attack_range
		
		if is_pad_aiming:
			var best_angle = 0.6 
			for enemy in nearby_enemies:
				if not is_instance_valid(enemy): continue
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= best_dist and has_line_of_sight(enemy):
					var dir_to_enemy = global_position.direction_to(enemy.global_position)
					var angle = abs(final_aim_dir.angle_to(dir_to_enemy))
					if angle < best_angle:
						best_angle = angle
						best_enemy = enemy
		
		if best_enemy == null and not is_pad_aiming:
			if last_target != null and is_instance_valid(last_target):
				var lp = last_target.get_parent()
				if lp and lp.is_in_group("Enemy"):
					var dist = global_position.distance_to(lp.global_position)
					if dist <= best_dist and has_line_of_sight(lp):
						best_enemy = lp
						best_dist = dist 
			
			for enemy in nearby_enemies:
				if not is_instance_valid(enemy): continue
				var dist = global_position.distance_to(enemy.global_position)
				if dist < best_dist and has_line_of_sight(enemy):
					best_dist = dist
					best_enemy = enemy
					
		if best_enemy != null:
			for child in best_enemy.get_children():
				if child is InteractableComponent:
					found_target = child
					found_is_enemy = true
					break

	elif is_pad_aiming and auto_enemy_selector and not found_is_enemy and not auto_lock_closest_enemy:
		var best_enemy = null
		var best_angle = 0.6 
		for enemy in nearby_enemies:
			if not is_instance_valid(enemy): continue
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= current_attack_range: 
				var dir_to_enemy = global_position.direction_to(enemy.global_position)
				var angle = abs(final_aim_dir.angle_to(dir_to_enemy))
				if angle < best_angle:
					best_angle = angle
					best_enemy = enemy
		if best_enemy != null:
			for child in best_enemy.get_children():
				if child is InteractableComponent:
					found_target = child
					found_is_enemy = true
					break

	# --- ZAMROŻENIE CELU (Hard Sticky Target) ---
	if (continuous_gamepad_aiming or auto_lock_closest_enemy) and not is_pad_aiming and current_target != null and is_instance_valid(current_target):
		var is_current_reachable = false
		var target_parent = current_target.get_parent()
		var current_is_enemy = target_parent and target_parent.is_in_group("Enemy")
		
		if current_is_enemy:
			if global_position.distance_to(target_parent.global_position) <= current_attack_range and has_line_of_sight(target_parent):
				is_current_reachable = true
		else:
			if global_position.distance_to(current_target.global_position) <= interaction_distance:
				is_current_reachable = true
				
		var allow_sticky = true
		if auto_enemy_selector and not current_is_enemy and found_is_enemy:
			allow_sticky = false 
			
		if is_current_reachable and allow_sticky:
			found_target = current_target
			found_is_enemy = current_is_enemy

	# 3. Zabezpieczenie fizyczne dystansu
	found_target = _enforce_distance_check(found_target, current_attack_range)

	# 4. Zarządzanie podświetlaniem 
	_manage_target_highlight(found_target, true, current_attack_range, is_pad_aiming)

## Oczyszcza aktualny cel i usuwa obrysowanie
func clear_gamepad_target():
	if current_target != null:
		current_target.untarget()
		current_target = null

# ==========================================
# FUNKCJE POMOCNICZE (Współdzielone)
# ==========================================

## Pobiera InteractableComponent z promienia lasera
func _get_raycast_target() -> InteractableComponent:
	var collider = aim_scanner.get_collider()
	if collider != null:
		if collider is InteractableComponent:
			return collider
		else:
			for child in collider.get_children():
				if child is InteractableComponent:
					return child
	return null

## Sprawdza i limituje obiekt pod kątem dystansu z zasięgiem broni
func _enforce_distance_check(target: InteractableComponent, current_attack_range: float) -> InteractableComponent:
	if target != null:
		var is_reachable = false
		var target_parent = target.get_parent()
		
		if target_parent and target_parent.is_in_group("Enemy"):
			var dist_to_enemy = global_position.distance_to(target_parent.global_position)
			if dist_to_enemy <= current_attack_range:
				is_reachable = true
		else:
			var dist_to_object = global_position.distance_to(target.global_position)
			# Sprawdzanie czy ściana nie blokuje skrzyni/przedmiotu ---
			if dist_to_object <= interaction_distance and has_line_of_sight(target):
				is_reachable = true
				
		if not is_reachable:
			return null
	return target

# Sprawdza, czy gracz ma czystą linię strzału/ciosu do celu (nie zasłaniają go ściany)
func has_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	
	# Wykluczamy samego gracza (rodzica komponentu) z kolizji promienia
	query.exclude = [get_parent().get_rid()]
	
	# Ważne: Jeśli twoje ściany mają specyficzną warstwę fizyki (Collision Layer), odkomentuj poniższą linię.
	# Domyślnie sprawdza wszystkie warstwy, co może zablokować atak na innej jednostce / przedmiocie.
	query.collision_mask = obstacles_mask # Ustaw maskę kolizji odpowiednią dla przeszkód (ścian)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		# Jeśli promień trafił we wroga, jego Hitbox (dziecko wroga) lub wróg jest dzieckiem trafionego obiektu
		if collider == target or target.is_ancestor_of(collider) or collider.is_ancestor_of(target):
			return true
		# W przeciwnym wypadku promień trafił w coś innego (np. w ścianę TileMap)
		return false
		
	# Jeśli promień w ogóle nic w nic nie uderzył, droga jest wolna (może się zdarzyć, gdy np. wróg nie ma włączonej kolizji)
	return true

## Odpowiada za podświetlanie, odznaczanie i zapisywanie "ostatniego" celu
func _manage_target_highlight(found_target: InteractableComponent, is_gamepad: bool, current_attack_range: float, is_pad_aiming: bool = false):
	if found_target != null:
		if current_target != found_target:
			clear_gamepad_target()
			current_target = found_target
			current_target.target()
			last_target = null
	else:
		if current_target != null:
			var should_drop = false
			var dropped_due_to_distance = false
			
			# --- LOGIKA GUBIENIA CELU ---
			if is_gamepad:
				# Odznacz jeśli celujemy padem, a laser zgubił obiekt
				if is_pad_aiming:
					should_drop = true
			else:
				# Myszka! Jeśli flaga 'sticky' jest wyłączona, odznaczamy natychmiast po zjechaniu kursorem
				if not sticky_mouse_aiming:
					should_drop = true
			
			if not should_drop and is_instance_valid(current_target):
				var is_still_reachable = false
				var target_parent = current_target.get_parent()
				
				if target_parent and target_parent.is_in_group("Enemy"):
					var dist = global_position.distance_to(target_parent.global_position)
					if dist <= current_attack_range:
						is_still_reachable = true
				else:
					var dist = global_position.distance_to(current_target.global_position)
					if dist <= interaction_distance:
						is_still_reachable = true
						
				if not is_still_reachable:
					should_drop = true
					dropped_due_to_distance = true 
			
			elif not is_instance_valid(current_target):
				should_drop = true
				
			if should_drop:
				if dropped_due_to_distance:
					last_target = current_target
				clear_gamepad_target()

## Zwraca namierzony obiekt (wroga LUB budynek)
func get_target_node() -> Node2D:
	if current_target != null:
		var potential_target = current_target.get_parent()
		# Sprawdzamy, czy to wróg LUB obiekt typu PlacedObject
		if potential_target.is_in_group("Enemy") or potential_target is PlacedObject:
			return potential_target
	return null

func is_target_enemy() -> bool :
	var potential_target = current_target.get_parent()
	if potential_target != null and potential_target.is_in_group("Enemy") :
		return true
	return false

func is_target_building() -> bool :
	var potential_target = current_target.get_parent()
	if potential_target is PlacedObject :
		return true
	return false

#endregion
