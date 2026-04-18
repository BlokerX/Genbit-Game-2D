extends Node2D
class_name PlayerAimController

## Przenosimy referencję do skanera (teraz jest bezpośrednim dzieckiem tego węzła)
@onready var aim_scanner: RayCast2D = $AimScanner

## Zasięg celownika (tylko interakcje nieposiadające ograniczonego dystansu)
@export var aim_distance: float = 4000.0
## Czy system ma automatycznie zrzucać focus z przedmiotów na wrogów (Pad/Klawiatura)?
@export var auto_enemy_selector: bool = true
## Czy system ma automatycznie namierzać najbliższego wroga i pamiętać ostatniego? (Priorytet dla walki na padzie/klawiaturze)
@export var auto_lock_closest_enemy: bool = true
## Czy celownik ma być aktywny cały czas (True), czy tylko podczas wychylania gałki/strzałek (False)?
@export var continuous_gamepad_aiming: bool = false
## Czy myszka ma trzymać cel dopóki z niego nie odejdziemy (True), czy odznaczać go od razu po zjechaniu kursorem w pustą przestrzeń (False)?
@export var sticky_mouse_aiming: bool = false

## Przechowujemy aktualnie namierzony obiekt przez celownik
var current_target: InteractableComponent = null
## Pamięta ostatni cel, który zgubiliśmy tylko przez to, że wybiegliśmy z zasięgu
var last_target: InteractableComponent = null

#region System celowania

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
	
	# 1. Odczyt wychylenia gałki/strzałek
	var aim_vector = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	if aim_vector != Vector2.ZERO:
		is_pad_aiming = true
		var raw_aim_dir = aim_vector.normalized()
		final_aim_dir = raw_aim_dir
		
		# Magnetyzm celownika
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
			
	# 2. Aktualizacja Raycastu
	aim_scanner.force_raycast_update()
	var found_target = _get_raycast_target()
	var found_is_enemy = false
	
	if found_target != null:
		var tp = found_target.get_parent()
		if tp and tp.is_in_group("Enemy"):
			found_is_enemy = true

	# --- NOWY SYSTEM PAMIĘCI I AUTO-CELOWANIA WROGÓW ---
	if auto_lock_closest_enemy and not found_is_enemy:
		var best_enemy = null
		var best_dist = current_attack_range
		
		# KROK 1: Sprawdźmy, czy gałka jest aktywnie wychylana. Jeśli tak, priorytet ma cel w kierunku wychylenia.
		if is_pad_aiming:
			var best_angle = 0.6 
			for enemy in get_tree().get_nodes_in_group("Enemy"):
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= best_dist and _has_line_of_sight(enemy):
					var dir_to_enemy = global_position.direction_to(enemy.global_position)
					var angle = abs(final_aim_dir.angle_to(dir_to_enemy))
					if angle < best_angle:
						best_angle = angle
						best_enemy = enemy
		
		# KROK 2: Jeśli nie używamy gałki (albo nikt nie stał na drodze promienia z KROKU 1), skanujemy otoczenie!
		if best_enemy == null and not is_pad_aiming:
			# a) Sprawdzamy "pamięć" (czyli last_target - wroga z którym walczyliśmy, ale uciekł na chwilę z zasięgu)
			if last_target != null and is_instance_valid(last_target):
				var lp = last_target.get_parent()
				if lp and lp.is_in_group("Enemy"):
					var dist = global_position.distance_to(lp.global_position)
					if dist <= best_dist and _has_line_of_sight(lp):
						best_enemy = lp
						best_dist = dist # Ustawiamy jego dystans jako punkt odniesienia
			
			# b) Skanujemy wszystkich wrogów. Jeśli znajdziemy jakiegoś wroga BLIŻEJ niż zapamiętany (lub jeśli pamięć jest pusta), obieramy nowy cel
			for enemy in get_tree().get_nodes_in_group("Enemy"):
				var dist = global_position.distance_to(enemy.global_position)
				# Zwróć uwagę na znak mniejszości (<). Nowy wróg musi być wyraźnie bliżej, aby nadpisać pamięć starego celu.
				if dist < best_dist and _has_line_of_sight(enemy):
					best_dist = dist
					best_enemy = enemy
					
		# Aplikowanie wybranego wroga do zmiennych
		if best_enemy != null:
			for child in best_enemy.get_children():
				if child is InteractableComponent:
					found_target = child
					found_is_enemy = true
					break

	# --- FALLBACK dla starszego ustawienia (opcjonalny, jeśli wyłączysz nową flagę) ---
	elif is_pad_aiming and auto_enemy_selector and not found_is_enemy and not auto_lock_closest_enemy:
		var best_enemy = null
		var best_angle = 0.6 
		for enemy in get_tree().get_nodes_in_group("Enemy"):
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
	# Podtrzymujemy fokus tak długo, jak cel żyje, jest w zasięgu i nie jest zasłonięty ścianą.
	if (continuous_gamepad_aiming or auto_lock_closest_enemy) and not is_pad_aiming and current_target != null and is_instance_valid(current_target):
		var is_current_reachable = false
		var target_parent = current_target.get_parent()
		var current_is_enemy = target_parent and target_parent.is_in_group("Enemy")
		
		if current_is_enemy:
			if global_position.distance_to(target_parent.global_position) <= current_attack_range and _has_line_of_sight(target_parent):
				is_current_reachable = true
		else:
			if global_position.distance_to(current_target.global_position) <= aim_distance:
				is_current_reachable = true
				
		var allow_sticky = true
		# Odepnij obecny podniesiony cel (np. przedmiot), jeśli mamy wroga na radarze i włączony priorytet
		if auto_enemy_selector and not current_is_enemy and found_is_enemy:
			allow_sticky = false 
			
		if is_current_reachable and allow_sticky:
			found_target = current_target
			found_is_enemy = current_is_enemy

	# 3. Zabezpieczenie fizyczne dystansu
	found_target = _enforce_distance_check(found_target, current_attack_range)

	# 4. Zarządzanie podświetlaniem (i uzupełnianie last_target gdy cel się oddala!)
	_manage_target_highlight(found_target, true, is_pad_aiming)

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
			if dist_to_object <= aim_distance:
				is_reachable = true
				
		if not is_reachable:
			return null
	return target

# Sprawdza, czy gracz ma czystą linię strzału/ciosu do celu (nie zasłaniają go ściany)
func _has_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	
	# Wykluczamy samego gracza (rodzica komponentu) z kolizji promienia
	query.exclude = [get_parent().get_rid()]
	
	# Ważne: Jeśli twoje ściany mają specyficzną warstwę fizyki (Collision Layer), odkomentuj poniższą linię.
	# Domyślnie sprawdza wszystkie warstwy, co może zablokować atak na innej jednostce / przedmiocie.
	query.collision_mask = 1 # Ustaw maskę kolizji odpowiednią dla przeszkód (ścian)
	
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
					if dist <= aim_distance:
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

## Zwraca namierzonego wroga lub tego, z którym się zderzamy. Zwraca null, jeśli brak wroga.
func _get_enemy_target() -> Node2D:
	# 1. Sprawdzamy celownik (RayCast/Myszka)
	if current_target != null:
		var potential_enemy = current_target.get_parent()
		if potential_enemy.is_in_group("Enemy"):
			return potential_enemy
			
	return null

#endregion
