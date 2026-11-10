extends Node
class_name ThreatAssessmentComponent
## Komponent analizy zagrożeń dla AI (obsługuje schodzenie z linii strzału gracza oraz omijanie min/pułapek).

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

@export_category("Skanowanie Zagrożeń")
@export var scan_radius: float = 350.0
@export var base_fear: float = 0.0
@export var max_fear: float = 0.95

var controller: AIController

# Flagi do strafingu
var _strafe_direction: float = 1.0
var _strafe_timer: float = 0.0

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller

func process_threats(delta: float) -> void:
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
					var dir_to_player: Vector2 = entity.global_position.direction_to(blackboard.target.global_position)
					var tangent: Vector2 = Vector2(-dir_to_player.y, dir_to_player.x) * _strafe_direction
					total_avoidance += tangent * (weapon_threat * STRAFE_WEIGHT_MULTIPLIER)

	# =========================================================================
	# 2. OMIJANIE PUŁAPEK I MIN (Analiza Węzłów Sceny)
	# =========================================================================
	var hazards: Array[Node] = get_tree().get_nodes_in_group("Hazard")
	for hazard in hazards:
		if not is_instance_valid(hazard) or not hazard is Node2D:
			continue
		if "shooter" in hazard and hazard.get("shooter") == entity:
			continue

		var hazard_2d: Node2D = hazard as Node2D
		var dist: float = entity.global_position.distance_to(hazard_2d.global_position)

		if dist < scan_radius:
			var hazard_threat: float = max_fear if dist < HAZARD_CLOSE_PANIC_DISTANCE_PX else HAZARD_DEFAULT_THREAT_LEVEL
			current_threat = maxf(current_threat, hazard_threat)

			var dir_to_hazard: Vector2 = entity.global_position.direction_to(hazard_2d.global_position)
			var dir_away: Vector2 = -dir_to_hazard

			var current_move_dir: Vector2 = entity.velocity.normalized()
			if current_move_dir == Vector2.ZERO and is_instance_valid(blackboard.target):
				current_move_dir = entity.global_position.direction_to(blackboard.target.global_position)

			# Jeśli AI idzie prosto na minę
			if current_move_dir.dot(dir_to_hazard) > HAZARD_HEAD_ON_DOT_THRESHOLD:
				var tangent: Vector2 = Vector2(-dir_to_hazard.y, dir_to_hazard.x)
				if current_move_dir.dot(tangent) < 0.0:
					tangent = -tangent
				dir_away = (dir_away + tangent * HAZARD_TANGENT_STEER_MULTIPLIER).normalized()

			var distance_weight: float = clampf(1.0 - (dist / maxf(1.0, scan_radius)), 0.0, 1.0)
			total_avoidance += dir_away * distance_weight * HAZARD_REPULSION_FORCE_WEIGHT

	blackboard.threat_level = clampf(current_threat, 0.0, 1.0)
	blackboard.avoidance_vector = total_avoidance

## Polimorficznie ocenia zagrożenie trzymanych komponentów przedmiotu (SOLID - OCP).
func _evaluate_weapon_threat(components: Array) -> float:
	var highest_threat: float = DEFAULT_UNARMED_THREAT_RATIO
	for comp in components:
		if comp is ItemComponent:
			highest_threat = maxf(highest_threat, (comp as ItemComponent).get_ai_threat_score())
	return highest_threat
