extends Node2D
class_name PlayerAimController
## Kontroler celowania gracza obsługujący tryb myszki oraz pada/klawiatury, priorytety celów i weryfikację linii wzroku (LoS).

# --- STAŁE KONFIGURACYJNE (Brak magicznych liczb) ---
const ALL_PHYSICS_LAYERS_MASK: int = 0xFFFFFFFF
const MAX_RAYCAST_PIERCE_STEPS: int = 10
const DEFAULT_COMBAT_RADIUS_PX: float = 20.0
const PLAYER_SELF_AIM_MARGIN_PX: float = 15.0
const MAGNETISM_MAX_ANGLE_RAD: float = 0.8
const AUTO_LOCK_CONE_ANGLE_RAD: float = 0.6

## Referencja do skanera promienia (RayCast2D).
@onready var aim_scanner: RayCast2D = $AimScanner
## Zasięg celownika (dla interakcji nieposiadających ograniczonego dystansu).
@export var aim_distance: float = 4000.0
## Maksymalny dystans do interakcji z obiektami (np. podnoszenie przedmiotów).
@export var interaction_distance: float = 150.0
## Czy system ma automatycznie zrzucać focus z przedmiotów na wrogów (Pad/Klawiatura)?
@export var auto_enemy_selector: bool = true
## Czy system ma automatycznie namierzać najbliższego wroga i pamiętać ostatniego?
@export var auto_lock_closest_enemy: bool = true
## Czy celownik ma być aktywny cały czas (True), czy tylko podczas wychylania gałki/strzałek (False)?
@export var continuous_gamepad_aiming: bool = false
## Czy po puszczeniu gałki laser ma znikać (wracać do zera)?
@export var hide_laser_on_stick_release: bool = true
## Czy myszka ma trzymać cel dopóki z niego nie odejdziemy (True), czy odznaczać go od razu po zjechaniu kursorem (False)?
@export var sticky_mouse_aiming: bool = false

## Maska kolizji dla ścian i twardych przeszkód terenowych.
@export_flags_2d_physics var obstacles_mask: int = 1

# --- ZMIENNE WIRTUALNEGO KURSORA (PAD) ---
var virtual_cursor_pos: Vector2 = Vector2.ZERO
@export var virtual_cursor_speed: float = 450.0

## Lokalna pamięć wrogów w pobliżu. Oszczędza zużycie procesora!
var nearby_enemies: Array[Node2D] = []

## Aktualnie namierzony obiekt przez celownik.
var current_target: InteractableComponent = null
## Pamięta ostatni cel, który zgubiliśmy tylko przez wybiegniecie z zasięgu.
var last_target: InteractableComponent = null

func _ready() -> void:
	var detection_area: Area2D = Area2D.new()
	detection_area.collision_layer = 0
	detection_area.collision_mask = ALL_PHYSICS_LAYERS_MASK

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = aim_distance
	collision_shape.shape = circle

	detection_area.add_child(collision_shape)
	add_child(detection_area)

	detection_area.body_entered.connect(_on_enemy_entered)
	detection_area.body_exited.connect(_on_enemy_exited)

	reset_virtual_cursor()

func _on_enemy_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy") and not nearby_enemies.has(body):
		nearby_enemies.append(body)

func _on_enemy_exited(body: Node2D) -> void:
	if nearby_enemies.has(body):
		nearby_enemies.erase(body)

#region System celowania
## Resetuje pozycję wirtualnego kursora na pozycji gracza.
func reset_virtual_cursor() -> void:
	virtual_cursor_pos = global_position

## Główna obsługa celowania wywoływana co klatkę fizyki.
func process_aiming(is_using_mouse: bool, current_attack_range: float, disable_targeting: bool = false) -> void:
	if is_using_mouse:
		handle_mouse_aiming(current_attack_range, disable_targeting)
	else:
		handle_gamepad_aiming(current_attack_range, disable_targeting)

## Celowanie za pomocą kursora myszy.
func handle_mouse_aiming(current_attack_range: float, disable_targeting: bool = false) -> void:
	var local_mouse_pos: Vector2 = get_local_mouse_position()
	aim_scanner.target_position = local_mouse_pos.limit_length(aim_distance)
	aim_scanner.force_raycast_update()

	var found_target: InteractableComponent = null
	if not disable_targeting:
		found_target = _get_raycast_target(true)

	found_target = _enforce_distance_check(found_target, current_attack_range)
	_manage_target_highlight(found_target, false, current_attack_range)

## Celowanie za pomocą pada lub klawiatury.
func handle_gamepad_aiming(current_attack_range: float, disable_targeting: bool = false) -> void:
	var final_aim_dir: Vector2 = Vector2.ZERO
	var is_pad_aiming: bool = false 

	# --- 1. AKTUALIZACJA WIRTUALNEGO KURSORA ---
	var aim_vector: Vector2 = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	if aim_vector != Vector2.ZERO:
		is_pad_aiming = true
		var delta: float = get_physics_process_delta_time()
		virtual_cursor_pos += aim_vector.normalized() * virtual_cursor_speed * delta

	var raw_aim_dir: Vector2 = aim_vector.normalized()
	if is_pad_aiming:
		final_aim_dir = raw_aim_dir
	else:
		final_aim_dir = global_position.direction_to(virtual_cursor_pos)
		if final_aim_dir == Vector2.ZERO:
			final_aim_dir = Vector2.DOWN

	# --- 2. USTAWIENIE SKANERA ---
	if not is_pad_aiming and hide_laser_on_stick_release and current_target == null:
		aim_scanner.target_position = Vector2.ZERO
	else:
		aim_scanner.target_position = final_aim_dir * aim_distance

	# --- 3. MAGNETYZM I ZATRZYMANIE NA CELU ---
	if not disable_targeting and current_target != null and is_instance_valid(current_target):
		var target_parent: Node2D = current_target.get_parent() as Node2D
		if target_parent != null:
			var dir_to_target: Vector2 = global_position.direction_to(target_parent.global_position)
			if raw_aim_dir != Vector2.ZERO and abs(raw_aim_dir.angle_to(dir_to_target)) < MAGNETISM_MAX_ANGLE_RAD:
				final_aim_dir = dir_to_target
				aim_scanner.target_position = final_aim_dir * aim_distance
			elif not is_pad_aiming:
				final_aim_dir = dir_to_target
				aim_scanner.target_position = final_aim_dir * aim_distance

	# --- SMYCZ WIRTUALNEGO KURSORA ---
	var limit_range: float = current_attack_range if current_attack_range > 0.0 else aim_distance
	if global_position.distance_to(virtual_cursor_pos) > limit_range:
		var dir_to_cursor: Vector2 = global_position.direction_to(virtual_cursor_pos)
		if dir_to_cursor == Vector2.ZERO: 
			dir_to_cursor = Vector2.DOWN
		virtual_cursor_pos = global_position + (dir_to_cursor * limit_range)

	aim_scanner.force_raycast_update()

	var found_target: InteractableComponent = null
	var found_is_enemy: bool = false

	if not disable_targeting:
		found_target = _get_raycast_target(false)
		if found_target != null and found_target.is_enemy_target():
			found_is_enemy = true

		# --- SYSTEM PAMIĘCI I AUTO-CELOWANIA WROGÓW ---
		if auto_lock_closest_enemy and not found_is_enemy:
			var best_enemy: Node2D = null
			var best_dist: float = current_attack_range

			if is_pad_aiming:
				var best_angle: float = AUTO_LOCK_CONE_ANGLE_RAD
				for enemy in nearby_enemies:
					if not is_instance_valid(enemy):
						continue
					var dist: float = get_edge_distance(enemy)
					if dist <= best_dist and has_line_of_sight(enemy):
						var dir_to_enemy: Vector2 = global_position.direction_to(enemy.global_position)
						var angle: float = abs(final_aim_dir.angle_to(dir_to_enemy))
						if angle < best_angle:
							best_angle = angle
							best_enemy = enemy

			if best_enemy == null and not is_pad_aiming:
				if last_target != null and is_instance_valid(last_target) and last_target.is_enemy_target():
					var lp: Node2D = last_target.get_parent() as Node2D
					if lp != null:
						var dist: float = get_edge_distance(lp)
						if dist <= best_dist and has_line_of_sight(lp):
							best_enemy = lp
							best_dist = dist 

				for enemy in nearby_enemies:
					if not is_instance_valid(enemy):
						continue
					var dist: float = get_edge_distance(enemy)
					if dist < best_dist and has_line_of_sight(enemy):
						best_dist = dist
						best_enemy = enemy

			if best_enemy != null:
				for child in best_enemy.get_children():
					if child is InteractableComponent:
						found_target = child as InteractableComponent
						found_is_enemy = true
						break

		elif is_pad_aiming and auto_enemy_selector and not found_is_enemy and not auto_lock_closest_enemy:
			var best_enemy: Node2D = null
			var best_angle: float = AUTO_LOCK_CONE_ANGLE_RAD
			for enemy in nearby_enemies:
				if not is_instance_valid(enemy):
					continue
				var dist: float = get_edge_distance(enemy)
				if dist <= current_attack_range: 
					var dir_to_enemy: Vector2 = global_position.direction_to(enemy.global_position)
					var angle: float = abs(final_aim_dir.angle_to(dir_to_enemy))
					if angle < best_angle:
						best_angle = angle
						best_enemy = enemy

			if best_enemy != null:
				for child in best_enemy.get_children():
					if child is InteractableComponent:
						found_target = child as InteractableComponent
						found_is_enemy = true
						break

		# --- ZAMROŻENIE CELU (Hard Sticky Target) ---
		if (continuous_gamepad_aiming or auto_lock_closest_enemy) and not is_pad_aiming and current_target != null and is_instance_valid(current_target):
			var is_current_reachable: bool = false
			var target_parent: Node2D = current_target.get_parent() as Node2D
			var current_is_enemy: bool = current_target.is_enemy_target()

			if current_is_enemy and target_parent != null:
				if global_position.distance_to(target_parent.global_position) <= current_attack_range and has_line_of_sight(target_parent):
					is_current_reachable = true
			else:
				if global_position.distance_to(current_target.global_position) <= interaction_distance:
					is_current_reachable = true

			var allow_sticky: bool = true
			if auto_enemy_selector and not current_is_enemy and found_is_enemy:
				allow_sticky = false 

			if is_current_reachable and allow_sticky:
				found_target = current_target
				found_is_enemy = current_is_enemy

	found_target = _enforce_distance_check(found_target, current_attack_range)
	_manage_target_highlight(found_target, true, current_attack_range, is_pad_aiming)

## Oczyszcza aktualny cel i usuwa obrysowanie.
func clear_gamepad_target() -> void:
	if current_target != null:
		current_target.untarget()
		current_target = null

# ==========================================
# FUNKCJE POMOCNICZE (Współdzielone)
# ==========================================

## Pobiera InteractableComponent z promienia lasera z uwzględnieniem priorytetów (SOLID - OCP).
func _get_raycast_target(is_mouse: bool = true) -> InteractableComponent:
	var hits: Array[InteractableComponent] = []
	var hard_blocker_hit: bool = false
	var cursor_global_pos: Vector2 = get_global_mouse_position() if is_mouse else virtual_cursor_pos

	aim_scanner.clear_exceptions()

	for _i in range(MAX_RAYCAST_PIERCE_STEPS):
		aim_scanner.force_raycast_update()
		var collider: Object = aim_scanner.get_collider()

		if collider == null:
			break

		var interactable: InteractableComponent = _extract_interactable(collider)
		if interactable != null:
			hits.append(interactable)
			# Pytamy bezpośrednio InteractableComponent, czy jest twardą przeszkodą (brak sprawdzania stringów!)
			if interactable.is_hard_aim_blocker():
				hard_blocker_hit = true
		else:
			# Trafiono obiekt bez interakcji (np. zwykłą ścianę) - przerywamy skanowanie!
			break

		if hard_blocker_hit:
			break

		if collider is CollisionObject2D:
			aim_scanner.add_exception(collider as CollisionObject2D)
		else:
			break

	aim_scanner.clear_exceptions()
	return _select_highest_priority_target(hits, cursor_global_pos)

## Rozpoznaje InteractableComponent w trafionym obiekcie fizycznym.
func _extract_interactable(collider: Object) -> InteractableComponent:
	if collider is InteractableComponent:
		return collider as InteractableComponent
	if collider is Node:
		for child in (collider as Node).get_children():
			if child is InteractableComponent:
				return child as InteractableComponent
	return null

## Sortuje trafienia na podstawie priorytetów z InteractableComponent i kolejności uderzenia.
func _select_highest_priority_target(hits: Array[InteractableComponent], cursor_global_pos: Vector2) -> InteractableComponent:
	var best_target: InteractableComponent = null
	var best_priority: int = -1

	for target in hits:
		var priority: int = _get_target_priority(target)

		# Zabezpieczenie: Zaznaczanie gracza tylko gdy kursor faktycznie na nim spoczywa
		if priority == InteractableComponent.AIM_PRIORITY_PLAYER:
			var target_radius: float = DEFAULT_COMBAT_RADIUS_PX
			if "combat_radius" in target:
				target_radius = float(target.get("combat_radius"))
			elif target.get_parent() != null and "combat_radius" in target.get_parent():
				target_radius = float(target.get_parent().get("combat_radius"))

			var parent: Node2D = target.get_parent() as Node2D
			var center_pos: Vector2 = parent.global_position if parent != null else target.global_position
			if center_pos.distance_to(cursor_global_pos) > (target_radius + PLAYER_SELF_AIM_MARGIN_PX):
				continue 

		if priority > best_priority:
			best_priority = priority
			best_target = target

	return best_target

## Deleguje pobranie priorytetu do InteractableComponent (Information Expert).
func _get_target_priority(target: InteractableComponent) -> int:
	if target == null:
		return InteractableComponent.AIM_PRIORITY_NONE
	return target.get_aim_priority()

## Sprawdza i limituje obiekt pod kątem dystansu z zasięgiem broni lub interakcji.
func _enforce_distance_check(target: InteractableComponent, current_attack_range: float) -> InteractableComponent:
	if target != null:
		var is_reachable: bool = false
		var target_parent: Node2D = target.get_parent() as Node2D

		if target.is_enemy_target() and target_parent != null:
			var dist_to_enemy: float = get_edge_distance(target_parent)
			if dist_to_enemy <= current_attack_range:
				is_reachable = true
		else:
			var dist_to_object: float = get_edge_distance(target)
			if dist_to_object <= interaction_distance and has_line_of_sight(target):
				is_reachable = true

		if not is_reachable:
			return null
	return target

## Sprawdza, czy gracz ma czystą linię wzroku/strzału do celu (nie zasłaniają go ściany).
func has_line_of_sight(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	if get_parent() is CollisionObject2D:
		query.exclude = [(get_parent() as CollisionObject2D).get_rid()]
	query.collision_mask = obstacles_mask

	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		var collider: Node = result.get("collider") as Node
		if collider == target or (collider != null and (target.is_ancestor_of(collider) or collider.is_ancestor_of(target))):
			return true
		return false
	return true

## Odpowiada za podświetlanie, odznaczanie i zapisywanie ostatniego celu.
func _manage_target_highlight(
	found_target: InteractableComponent,
	is_gamepad: bool,
	current_attack_range: float,
	is_pad_aiming: bool = false
) -> void:
	if found_target != null:
		if current_target != found_target:
			clear_gamepad_target()
			current_target = found_target
			current_target.target()
		last_target = null
	else:
		if current_target != null:
			var should_drop: bool = false
			var dropped_due_to_distance: bool = false

			if is_gamepad:
				if is_pad_aiming:
					should_drop = true
			else:
				if not sticky_mouse_aiming:
					should_drop = true

			if not should_drop and is_instance_valid(current_target):
				var is_still_reachable: bool = false
				var target_parent: Node2D = current_target.get_parent() as Node2D
				if current_target.is_enemy_target() and target_parent != null:
					var dist: float = get_edge_distance(target_parent)
					if dist <= current_attack_range:
						is_still_reachable = true
				else:
					var dist: float = get_edge_distance(current_target)
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

## Zwraca namierzony obiekt (wroga LUB budynek).
func get_target_node() -> Node2D:
	if current_target != null and is_instance_valid(current_target):
		if current_target.is_enemy_target() or current_target.is_building_target():
			return current_target.get_parent() as Node2D
	return null

func is_target_enemy() -> bool:
	return current_target != null and is_instance_valid(current_target) and current_target.is_enemy_target()

func is_target_building() -> bool:
	return current_target != null and is_instance_valid(current_target) and current_target.is_building_target()

func get_edge_distance(target_node: Variant) -> float:
	if not is_instance_valid(target_node) or not (target_node is Node2D):
		return INF
	var origin_node: Node2D = get_parent() as Node2D if get_parent() is Node2D else self
	return CharacterEntity.get_edge_distance_between(origin_node, target_node)

#endregion
