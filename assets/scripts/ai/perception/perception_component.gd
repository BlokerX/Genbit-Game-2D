extends Node
class_name PerceptionComponent
## Komponent percepcji AI odpowiedzialny za wykrywanie wrogich postaci w zasięgu wzroku (LoS)
## oraz reagowanie na ostrzał (przelatujące w pobliżu pociski wroga).

const DEFAULT_COMBAT_RADIUS_PX: float = 20.0
const DEFAULT_PROJECTILE_ALERT_RADIUS_PX: float = 260.0

@export var detection_distance: float = 600.0
## Promień wokół AI, w którym przelatujący wrogi pocisk alarmuje jednostkę o obecności strzelca.
@export var projectile_alert_radius: float = DEFAULT_PROJECTILE_ALERT_RADIUS_PX
@export var los_ray: RayCast2D
var controller: AIController

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
	if not my_faction:
		return

	var best_target: CharacterEntity = null
	var best_distance: float = detection_distance

	for potential_target in get_tree().get_nodes_in_group("Character"):
		if not is_instance_valid(potential_target) or potential_target == entity:
			continue

		# --- Ignorowanie Niewidzialnych i Martwych celów ---
		if potential_target.get("is_dead") == true or potential_target.has_meta("is_invisible"):
			continue

		var disposition: int = my_faction.get_disposition_toward(potential_target)

		# AI zaatakuje TYLKO sprowokowanych i otwartych wrogów
		if disposition == FactionComponent.Disposition.HOSTILE:
			var my_rad: float = float(entity.combat_radius) if "combat_radius" in entity else DEFAULT_COMBAT_RADIUS_PX
			var target_rad: float = float(potential_target.combat_radius) if "combat_radius" in potential_target else DEFAULT_COMBAT_RADIUS_PX
			var edge_dist: float = maxf(0.0, entity.global_position.distance_to(potential_target.global_position) - (my_rad + target_rad))

			if edge_dist < best_distance and can_see_target(potential_target):
				best_distance = edge_dist
				best_target = potential_target as CharacterEntity

	# Jeśli nie znaleziono celu bezpośrednio, sprawdzamy czy obok AI nie przelatuje wrogi pocisk
	if best_target == null:
		best_target = _detect_incoming_projectile_shooter(entity, my_faction)

	blackboard.target = best_target

## Wykrywa strzelca, jeśli w pobliżu AI przelatuje wrogi pocisk lub rzutka z grupy "Hazard".
func _detect_incoming_projectile_shooter(entity: CharacterEntity, my_faction: FactionComponent) -> CharacterEntity:
	if projectile_alert_radius <= 0.0:
		return null

	for hazard in get_tree().get_nodes_in_group("Hazard"):
		if not is_instance_valid(hazard) or hazard.is_queued_for_deletion() or not (hazard is Node2D):
			continue
		if not ("shooter" in hazard):
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

		var dist_to_hazard: float = entity.global_position.distance_to((hazard as Node2D).global_position)
		if dist_to_hazard <= projectile_alert_radius:
			if my_faction.get_disposition_toward(shooter) == FactionComponent.Disposition.HOSTILE:
				return shooter

	return null

func can_see_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or not controller or not is_instance_valid(controller.entity):
		return false
	var entity: CharacterEntity = controller.entity

	if entity.global_position.distance_to(target.global_position) > detection_distance:
		return false

	if los_ray:
		los_ray.target_position = entity.to_local(target.global_position)
		los_ray.force_raycast_update()
		if los_ray.is_colliding():
			var col: Node = los_ray.get_collider() as Node
			return col == target or (col != null and (target.is_ancestor_of(col) or col.is_ancestor_of(target)))
		else:
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
