extends Node
class_name ThreatAssessmentComponent
## Komponent analizy zagrożeń dla AI (obsługuje schodzenie z linii strzału gracza,
## boczne unikanie nadlatujących pocisków z broni palnej oraz omijanie min i pułapek).

# --- STAŁE KONFIGURACYJNE (Brak magicznych liczb) ---
const STRAFE_CHANGE_MIN_SEC: float = 0.8
const STRAFE_CHANGE_MAX_SEC: float = 2.5
const STRAFE_EVASION_THREAT_THRESHOLD: float = 0.7
const STRAFE_WEIGHT_MULTIPLIER: float = 1.5

const HAZARD_CLOSE_PANIC_DISTANCE_PX: float = 150.0
const HAZARD_DEFAULT_THREAT_LEVEL: float = 0.95
const HAZARD_HEAD_ON_DOT_THRESHOLD: float = 0.3
const HAZARD_TANGENT_STEER_MULTIPLIER: float = 3.0
const HAZARD_REPULSION_FORCE_WEIGHT: float = 4.0
const DEFAULT_UNARMED_THREAT_RATIO: float = 0.10

# Stałe detekcji trajektorii pocisków (Zadanie 6)
const MIN_PROJECTILE_SPEED_FOR_SIDESTEP: float = 25.0
const INCOMING_PROJECTILE_DOT_MIN: float = 0.15
const PROJECTILE_DANGER_CORRIDOR_MARGIN_PX: float = 90.0
const PROJECTILE_SIDESTEP_FORCE_WEIGHT: float = 4.5
const DEFAULT_ENTITY_COMBAT_RADIUS_PX: float = 20.0
const MIN_LATERAL_OFFSET_PX: float = 1.0
const MIN_URGENCY_FACTOR: float = 0.3

@export_category("Skanowanie Zagrożeń")
## Promień wykrywania stacjonarnych zagrożeń (min, granatów, plam kwasu).
@export var scan_radius: float = 350.0
## Promień wczesnego wykrywania szybkich pocisków nadlatujących z broni palnej.
@export var projectile_scan_radius: float = 450.0
@export var base_fear: float = 0.0
@export var max_fear: float = 0.95

var controller: AIController

# Flagi do strafingu
var _strafe_direction: float = 1.0
var _strafe_timer: float = 0.0

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller

func process_threats(delta: float) -> void:
	if controller == null or not is_instance_valid(controller.entity):
		return

	var blackboard: AIBlackboard = controller.blackboard
	var entity: CharacterEntity = controller.entity
	var profile: AIBehaviorProfile = controller.behavior_profile

	if not profile or not profile.intelligent_movement:
		return

	var total_avoidance: Vector2 = Vector2.ZERO
	var current_threat: float = base_fear

	# Zmiana kierunku strafingu co losowy czas (aby AI "zygzakowało")
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_direction = 1.0 if randf() > 0.5 else -1.0
		_strafe_timer = randf_range(STRAFE_CHANGE_MIN_SEC, STRAFE_CHANGE_MAX_SEC)

	# =========================================================================
	# 1. OCENA BRONI GRACZA (Schodzenie z lufy - Kiting & Strafing)
	# =========================================================================
	if is_instance_valid(blackboard.target) and blackboard.target.has_method("get_inventory"):
		var inv = blackboard.target.get_inventory()
		if inv:
			var weapon: ItemInstance = inv.get_current_item()
			if weapon and weapon.data and weapon.data.components:
				var weapon_threat: float = _evaluate_weapon_threat(weapon.data.components)
				current_threat = maxf(current_threat, weapon_threat)

				if weapon_threat >= STRAFE_EVASION_THREAT_THRESHOLD:
					# Zamiast uciekać do tyłu, schodzimy BOKIEM (prostopadle do linii celowania gracza)
					var dir_to_player: Vector2 = entity.global_position.direction_to(blackboard.target.global_position)
					var tangent: Vector2 = Vector2(-dir_to_player.y, dir_to_player.x) * _strafe_direction
					total_avoidance += tangent * (weapon_threat * STRAFE_WEIGHT_MULTIPLIER)

	# =========================================================================
	# 2. OMIJANIE POCISKÓW, RZUTEK, PUŁAPEK I MIN (Analiza Węzłów z grupy "Hazard")
	# =========================================================================
	var hazards: Array[Node] = get_tree().get_nodes_in_group("Hazard")
	var my_radius: float = float(entity.combat_radius) if "combat_radius" in entity else DEFAULT_ENTITY_COMBAT_RADIUS_PX

	for hazard in hazards:
		if not is_instance_valid(hazard) or hazard.is_queued_for_deletion() or not (hazard is Node2D):
			continue

		var hazard_shooter: Node2D = _get_valid_hazard_shooter(hazard)
		# AI nie ucieka przed własnymi pociskami ani minami
		if hazard_shooter == entity:
			continue

		# Sprawdzamy, czy pocisk/mina należy do sojusznika (i ma wyłączony friendly_fire)
		var fallback_faction: StringName = _get_hazard_fallback_faction(hazard)
		if FactionComponent.is_ally_of(hazard_shooter, entity, fallback_faction):
			var has_ff: bool = bool(hazard.get("friendly_fire")) if "friendly_fire" in hazard else false
			if not has_ff:
				continue

		var hazard_2d: Node2D = hazard as Node2D
		var dist: float = entity.global_position.distance_to(hazard_2d.global_position)
		var hazard_velocity: Vector2 = _extract_hazard_velocity(hazard_2d)

		# --- WARIANT A: SZYBKI POCISK W LOCIE (Uskok prostopadły do trajektorii lotu) ---
		if hazard_velocity.length() >= MIN_PROJECTILE_SPEED_FOR_SIDESTEP:
			var effective_proj_radius: float = maxf(scan_radius, projectile_scan_radius)
			if dist <= effective_proj_radius:
				var sidestep_vec: Vector2 = _calculate_projectile_sidestep(
					entity.global_position,
					my_radius,
					hazard_2d.global_position,
					hazard_velocity,
					dist,
					effective_proj_radius
				)
				if sidestep_vec != Vector2.ZERO:
					var proj_threat: float = max_fear if dist < HAZARD_CLOSE_PANIC_DISTANCE_PX else HAZARD_DEFAULT_THREAT_LEVEL
					current_threat = maxf(current_threat, proj_threat)
					total_avoidance += sidestep_vec
			continue

		# --- WARIANT B: ZAGROŻENIE STACJONARNE / POWOLNE (Mina, Granat na ziemi) ---
		if dist < scan_radius:
			var hazard_threat: float = max_fear if dist < HAZARD_CLOSE_PANIC_DISTANCE_PX else HAZARD_DEFAULT_THREAT_LEVEL
			current_threat = maxf(current_threat, hazard_threat)

			var dir_to_hazard: Vector2 = entity.global_position.direction_to(hazard_2d.global_position)
			var dir_away: Vector2 = -dir_to_hazard

			var current_move_dir: Vector2 = entity.velocity.normalized()
			if current_move_dir == Vector2.ZERO and is_instance_valid(blackboard.target):
				current_move_dir = entity.global_position.direction_to(blackboard.target.global_position)

			# Jeśli AI idzie prosto na minę, odchylamy wektor ucieczki w bok (styczna)
			if current_move_dir.dot(dir_to_hazard) > HAZARD_HEAD_ON_DOT_THRESHOLD:
				var tangent: Vector2 = Vector2(-dir_to_hazard.y, dir_to_hazard.x)
				if current_move_dir.dot(tangent) < 0.0:
					tangent = -tangent
				dir_away = (dir_away + tangent * HAZARD_TANGENT_STEER_MULTIPLIER).normalized()

			var distance_weight: float = clampf(1.0 - (dist / maxf(1.0, scan_radius)), 0.0, 1.0)
			total_avoidance += dir_away * distance_weight * HAZARD_REPULSION_FORCE_WEIGHT

	blackboard.threat_level = clampf(current_threat, 0.0, 1.0)
	blackboard.avoidance_vector = total_avoidance

## Bezpiecznie pobiera referencję strzelca jako Variant przed rzutowaniem (chroni przed błędem 'Trying to cast a freed object').
func _get_valid_hazard_shooter(hazard: Node) -> Node2D:
	if not ("shooter" in hazard):
		return null
	var raw_shooter: Variant = hazard.get("shooter")
	if is_instance_valid(raw_shooter) and raw_shooter is Node2D:
		return raw_shooter as Node2D
	if raw_shooter != null:
		hazard.set("shooter", null)
	return null

## Pobiera zapamiętaną nazwę frakcji strzelca z pocisku lub kontrolera wybuchu.
func _get_hazard_fallback_faction(hazard: Node) -> StringName:
	if "_shooter_faction_name" in hazard:
		return hazard.get("_shooter_faction_name")
	if "_explosive_ctrl" in hazard:
		var ctrl: Variant = hazard.get("_explosive_ctrl")
		if ctrl != null and "shooter_faction_name" in ctrl:
			return ctrl.shooter_faction_name
	return &""

## Odczytuje aktualny wektor prędkości zagrożenia (obsługuje Projectile, ThrowableProjectile i ThrowablePhysics).
func _extract_hazard_velocity(hazard: Node2D) -> Vector2:
	if "direction" in hazard and "speed" in hazard:
		return Vector2(hazard.get("direction")) * float(hazard.get("speed"))
	if "current_velocity" in hazard:
		var cur_vel: Vector2 = Vector2(hazard.get("current_velocity"))
		if cur_vel.length_squared() > 1.0:
			return cur_vel
	if hazard is RigidBody2D:
		return (hazard as RigidBody2D).linear_velocity
	return Vector2.ZERO

## Oblicza wektor uskoku bocznego (prostopadłego do linii strzału), jeśli pocisk zmierza w korytarz kolizyjny AI.
func _calculate_projectile_sidestep(
	entity_pos: Vector2,
	entity_radius: float,
	proj_pos: Vector2,
	proj_velocity: Vector2,
	dist_to_proj: float,
	max_detect_radius: float
) -> Vector2:
	var proj_dir: Vector2 = proj_velocity.normalized()
	var proj_to_entity: Vector2 = entity_pos - proj_pos

	# Sprawdzamy, czy pocisk faktycznie zbliża się do AI (a nie minął go już i leci za plecami)
	if proj_dir.dot(proj_to_entity.normalized()) <= INCOMING_PROJECTILE_DOT_MIN:
		return Vector2.ZERO

	# Rzutujemy pozycję AI na półprostą lotu pocisku, wyznaczając najkrótszą odległość od osi strzału
	var projection_dist: float = maxf(0.0, proj_to_entity.dot(proj_dir))
	var closest_point_on_ray: Vector2 = proj_pos + (proj_dir * projection_dist)
	var lateral_offset: Vector2 = entity_pos - closest_point_on_ray
	var lateral_dist: float = lateral_offset.length()
	var danger_corridor: float = entity_radius + PROJECTILE_DANGER_CORRIDOR_MARGIN_PX

	if lateral_dist > danger_corridor:
		return Vector2.ZERO

	# Kierunek uskoku jest zawsze prostopadły do toru lotu pocisku
	var sidestep_dir: Vector2
	if lateral_dist >= MIN_LATERAL_OFFSET_PX:
		sidestep_dir = lateral_offset.normalized()
	else:
		sidestep_dir = Vector2(-proj_dir.y, proj_dir.x) * _strafe_direction

	var corridor_urgency: float = clampf(1.0 - (lateral_dist / maxf(1.0, danger_corridor)), MIN_URGENCY_FACTOR, 1.0)
	var distance_urgency: float = clampf(1.0 - (dist_to_proj / maxf(1.0, max_detect_radius)), MIN_URGENCY_FACTOR, 1.0)
	return sidestep_dir * corridor_urgency * distance_urgency * PROJECTILE_SIDESTEP_FORCE_WEIGHT

## Polimorficznie ocenia zagrożenie trzymanych komponentów przedmiotu (SOLID - OCP).
func _evaluate_weapon_threat(components: Array) -> float:
	var highest_threat: float = DEFAULT_UNARMED_THREAT_RATIO
	for comp in components:
		if comp is ItemComponent:
			highest_threat = maxf(highest_threat, (comp as ItemComponent).get_ai_threat_score())
	return highest_threat
