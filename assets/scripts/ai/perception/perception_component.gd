extends Node
class_name PerceptionComponent
## Komponent percepcji AI odpowiedzialny za wykrywanie wrogich postaci w zasięgu wzroku (LoS)
## oraz reagowanie na ostrzał (przelatujące w pobliżu pociski wroga).
## Wykorzystuje współdzielony cache grup na klatkę fizyki oraz szybkie filtrowanie distance_squared_to.

const DEFAULT_COMBAT_RADIUS_PX: float = 20.0
const DEFAULT_PROJECTILE_ALERT_RADIUS_PX: float = 260.0
## Czas ważności pamięci podręcznej pojedynczego testu linii wzroku (zapobiega podwójnym RayCastom w tej samej klatce).
const LOS_CACHE_DURATION_SEC: float = 0.06

@export var detection_distance: float = 600.0
## Promień wokół AI, w którym przelatujący wrogi pocisk alarmuje jednostkę o obecności strzelca.
@export var projectile_alert_radius: float = DEFAULT_PROJECTILE_ALERT_RADIUS_PX
@export var los_ray: RayCast2D

var controller: AIController

# Pamięć podręczna ostatniego testu linii wzroku (LoS) dla aktualnego celu
var _cached_los_target_id: int = 0
var _cached_los_result: bool = false
var _cached_los_timestamp_msec: int = 0

# =========================================================================
# WSPÓŁDZIELONY CACHE GRUP NA KLATKĘ FIZYKI (Optymalizacja O(1) dla roju AI)
# =========================================================================
static var _cached_characters_frame: int = -1
static var _cached_characters: Array[Node] = []
static var _cached_hazards_frame: int = -1
static var _cached_hazards: Array[Node] = []

## Zwraca listę węzłów z grupy "Character", pobierając ją z drzewa sceny maksymalnie 1 raz na klatkę fizyki.
static func get_shared_characters(tree: SceneTree) -> Array[Node]:
	if tree == null:
		return []
	var current_frame: int = Engine.get_physics_frames()
	if _cached_characters_frame != current_frame:
		_cached_characters_frame = current_frame
		_cached_characters = tree.get_nodes_in_group("Character")
	return _cached_characters

## Zwraca listę węzłów z grupy "Hazard", pobierając ją z drzewa sceny maksymalnie 1 raz na klatkę fizyki.
static func get_shared_hazards(tree: SceneTree) -> Array[Node]:
	if tree == null:
		return []
	var current_frame: int = Engine.get_physics_frames()
	if _cached_hazards_frame != current_frame:
		_cached_hazards_frame = current_frame
		_cached_hazards = tree.get_nodes_in_group("Hazard")
	return _cached_hazards

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	if not los_ray and controller.entity:
		los_ray = controller.entity.get_node_or_null("LineOfSight") as RayCast2D

func process_perception(_delta: float) -> void:
	if controller == null or not is_instance_valid(controller.entity):
		return

	var entity: CharacterEntity = controller.entity
	var blackboard: AIBlackboard = controller.blackboard
	var my_faction: FactionComponent = entity.faction_component
	if not my_faction:
		my_faction = entity.get_node_or_null("FactionComponent") as FactionComponent
		entity.faction_component = my_faction
	if not my_faction:
		return

	var best_target: CharacterEntity = null
	var best_distance: float = detection_distance
	var entity_pos: Vector2 = entity.global_position
	var my_rad: float = entity.get_effective_combat_radius()
	var tree: SceneTree = get_tree()

	for potential_target in get_shared_characters(tree):
		if not is_instance_valid(potential_target) or potential_target == entity or potential_target.is_queued_for_deletion():
			continue

		# --- Ignorowanie Niewidzialnych i Martwych celów ---
		if potential_target.get("is_dead") == true or potential_target.has_meta("is_invisible"):
			continue

		var target_2d: Node2D = potential_target as Node2D
		if target_2d == null:
			continue

		# OPTYMALIZACJA: Szybki test kwadratu odległości ZANIM odpytamy FactionComponent lub RayCast2D!
		var target_rad: float = CharacterEntity.get_effective_radius_of(target_2d)
		var max_allowed_center_dist: float = best_distance + my_rad + target_rad
		var dist_sq: float = entity_pos.distance_squared_to(target_2d.global_position)
		if dist_sq >= max_allowed_center_dist * max_allowed_center_dist:
			continue

		# AI zaatakuje TYLKO sprowokowanych i otwartych wrogów
		if my_faction.get_disposition_toward(target_2d) == FactionComponent.Disposition.HOSTILE:
			var edge_dist: float = maxf(0.0, sqrt(dist_sq) - (my_rad + target_rad))
			if edge_dist < best_distance and can_see_target(target_2d):
				best_distance = edge_dist
				best_target = target_2d as CharacterEntity

	# Jeśli nie znaleziono celu bezpośrednio, sprawdzamy czy obok AI nie przelatuje wrogi pocisk
	if best_target == null:
		best_target = _detect_incoming_projectile_shooter(entity, entity_pos, my_faction, tree)

	blackboard.target = best_target

## Wykrywa strzelca, jeśli w pobliżu AI przelatuje wrogi pocisk lub rzutka z grupy "Hazard".
func _detect_incoming_projectile_shooter(
	entity: CharacterEntity,
	entity_pos: Vector2,
	my_faction: FactionComponent,
	tree: SceneTree
) -> CharacterEntity:
	if projectile_alert_radius <= 0.0:
		return null

	var alert_radius_sq: float = projectile_alert_radius * projectile_alert_radius
	for hazard in get_shared_hazards(tree):
		if not is_instance_valid(hazard) or hazard.is_queued_for_deletion() or not (hazard is Node2D):
			continue
		if not ("shooter" in hazard):
			continue

		# Szybki filtr kwadratu dystansu przed odczytem strzelca
		if entity_pos.distance_squared_to((hazard as Node2D).global_position) > alert_radius_sq:
			continue

		# Bezpieczny odczyt przez Variant PRZED rzutowaniem (chroni przed błędem 'Trying to cast a freed object')
		var raw_shooter: Variant = hazard.get("shooter")
		if not is_instance_valid(raw_shooter) or not (raw_shooter is CharacterEntity):
			if raw_shooter != null:
				hazard.set("shooter", null)
			continue

		var shooter: CharacterEntity = raw_shooter as CharacterEntity
		if shooter == entity or shooter.get("is_dead") == true or shooter.has_meta("is_invisible"):
			continue

		if my_faction.get_disposition_toward(shooter) == FactionComponent.Disposition.HOSTILE:
			return shooter

	return null

func can_see_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or not controller or not is_instance_valid(controller.entity):
		return false
	var entity: CharacterEntity = controller.entity

	var max_dist_sq: float = detection_distance * detection_distance
	if entity.global_position.distance_squared_to(target.global_position) > max_dist_sq:
		return false

	# Sprawdzenie krótkotrwałego cache'u LoS (unika podwójnego RayCasta w tej samej klatce dla percepcji i walki)
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var cache_limit_msec: int = int(LOS_CACHE_DURATION_SEC * 1000.0)
	if target_id == _cached_los_target_id and (now_msec - _cached_los_timestamp_msec) <= cache_limit_msec:
		return _cached_los_result

	var is_visible_to_ai: bool = _perform_los_raycast(entity, target)
	_cached_los_target_id = target_id
	_cached_los_result = is_visible_to_ai
	_cached_los_timestamp_msec = now_msec
	return is_visible_to_ai

func _perform_los_raycast(entity: CharacterEntity, target: Node2D) -> bool:
	if los_ray:
		los_ray.target_position = entity.to_local(target.global_position)
		los_ray.force_raycast_update()
		if los_ray.is_colliding():
			var col: Node = los_ray.get_collider() as Node
			return col == target or (col != null and (target.is_ancestor_of(col) or col.is_ancestor_of(target)))
		return true

	# KULOODPORNY FALLBACK: Używamy wirtualnego promienia fizyki
	var space_state: PhysicsDirectSpaceState2D = entity.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(entity.global_position, target.global_position)
	query.exclude = [entity.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		var col: Node = result.get("collider") as Node
		return col == target or (col != null and (target.is_ancestor_of(col) or col.is_ancestor_of(target)))

	return true
