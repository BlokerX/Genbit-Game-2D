extends Node
class_name AIController
## Główny kontroler sztucznej inteligencji łączący percepcję, ocenę zagrożeń, maszynę stanów,
## nawigację, walkę oraz fazy bossa. Zawiera optymalizację rozkładania skanów percepcji w czasie.

const DEFAULT_IDLE_PERCEPTION_INTERVAL_SEC: float = 0.15
const DEFAULT_COMBAT_PERCEPTION_INTERVAL_SEC: float = 0.08

var entity: AICharacterEntity
var blackboard: AIBlackboard
var _perception_timer: float = 0.0

@export_category("Główne Profile")
## Profil zachowania definiujący zasięg widzenia, dystans zatrzymywania się (min_stopping_distance) i prędkość obrotu.
@export var behavior_profile: AIBehaviorProfile

@export_category("Optymalizacja Wydajności AI")
## Częstotliwość pełnego skanowania wzroku (w sekundach), gdy AI nie widzi wroga (0.0 = co klatkę fizyki).
@export_range(0.0, 0.5, 0.01) var perception_interval_idle: float = DEFAULT_IDLE_PERCEPTION_INTERVAL_SEC
## Częstotliwość pełnego skanowania wzroku (w sekundach), gdy AI jest w aktywnej walce (0.0 = co klatkę fizyki).
@export_range(0.0, 0.25, 0.01) var perception_interval_combat: float = DEFAULT_COMBAT_PERCEPTION_INTERVAL_SEC

@export_category("Komponenty Modułowe")
## Odpowiada za zmysły (wzrok, zasięg widzenia) i wykrywanie celów (Gracza) w otoczeniu.
@export var perception: PerceptionComponent
## Mózg AI zarządzający logiką stanów i decyzyjnością (Idle, Chase, Search, etc.).
@export var state_machine: AIStateMachine
## Odpowiada za fizyczne poruszanie się po siatce NavigationRegion2D oraz wyznaczanie ścieżek.
@export var navigation: AINavigationController
## Kontroluje logikę walki, dobór odpowiedniej broni z AIInventoryController oraz moment oddania strzału.
@export var combat: AICombatController
## Analizuje zagrożenia (broń gracza, miny, pociski) i oblicza wektor unikania (strafing/omijanie).
@export var threat_assessment: ThreatAssessmentComponent
## Zarządza fazami zdrowia Bossa (zmiana zachowania, nowe umiejętności i leczenie po spadku HP poniżej progu).
@export var phase_controller: AIPhaseController

func initialize(owner_entity: AICharacterEntity) -> void:
	entity = owner_entity
	blackboard = AIBlackboard.new()
	blackboard.initialize(entity)

	# Losowe przesunięcie fazowe zegara percepcji sprawia, że dziesiątki wrogów na mapie
	# nie wykonują kosztownych RayCastów w tej samej klatce fizyki!
	_perception_timer = randf_range(0.0, maxf(0.02, perception_interval_idle))

	if not behavior_profile:
		push_error("AIController: Brak AIBehaviorProfile!")

	# AUTO-RESOLVE komponentów (działa zarówno z przypisaniem w Inspektorze, jak i po nazwie dziecka)
	if not perception:
		perception = get_node_or_null("PerceptionComponent") as PerceptionComponent
	if not state_machine:
		state_machine = get_node_or_null("AIStateMachine") as AIStateMachine
	if not navigation:
		navigation = get_node_or_null("AINavigationController") as AINavigationController
	if not combat:
		combat = get_node_or_null("AICombatController") as AICombatController
	if not threat_assessment:
		threat_assessment = get_node_or_null("ThreatAssessmentComponent") as ThreatAssessmentComponent
	if not phase_controller:
		phase_controller = get_node_or_null("AIPhaseController") as AIPhaseController

	if perception:
		if behavior_profile:
			perception.detection_distance = behavior_profile.detection_distance
		perception.initialize(self)

	if state_machine:
		state_machine.initialize(self)
	if navigation:
		navigation.initialize(self)
	if combat:
		combat.initialize(self)
	if phase_controller:
		phase_controller.initialize(self)
	if threat_assessment:
		threat_assessment.initialize(self)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(entity) or entity.is_dead:
		return

	# 1. Zoptymalizowana aktualizacja percepcji (rozłożona w czasie między jednostkami)
	if perception:
		_process_perception_scheduled(delta)

	# 2. Ocena zagrożeń, stany, nawigacja i walka
	if threat_assessment:
		threat_assessment.process_threats(delta)
	if state_machine:
		state_machine.process_physics(delta)
	if navigation:
		navigation.process_navigation(delta)
	if combat:
		combat.process_combat(delta)

func _process_perception_scheduled(delta: float) -> void:
	# Natychmiastowe odpięcie celu, jeśli zginął lub włączył niewidzialność między skanami
	if blackboard.target != null:
		if (
			not is_instance_valid(blackboard.target)
			or blackboard.target.get("is_dead") == true
			or blackboard.target.has_meta("is_invisible")
		):
			blackboard.target = null
			_perception_timer = 0.0

	_perception_timer -= delta
	if _perception_timer <= 0.0:
		perception.process_perception(delta)
		var interval: float = perception_interval_combat if blackboard.target != null else perception_interval_idle
		_perception_timer = interval

# =========================================================================
# SYSTEM WYBUDZANIA (Wywoływane przez wyższą klasę w trakcie streamingu)
# =========================================================================

## Twardy reset pamięci i stanu potwora. 
## Czyści fałszywe cele i wymusza powrót do swobodnego zachowania.
func reset_state() -> void:
	# 1. Całkowite czyszczenie tablicy pamięci (Blackboard)
	if blackboard:
		blackboard.target = null
		blackboard.has_last_known_position = false
		blackboard.want_to_move = false
		blackboard.avoidance_vector = Vector2.ZERO
		blackboard.threat_level = 0.0

	# --- NAPRAWA A: RESET NAWIGACJI ---
	# Kasujemy starą ścieżkę, nakazując AI nawigować "do samego siebie".
	if navigation and navigation.nav_agent:
		navigation.nav_agent.target_position = entity.global_position

	# 2. Reset maszyny stanów do bezpiecznego punktu wyjścia
	if state_machine:
		state_machine.change_state("Idle")

	_perception_timer = 0.0
	print("[AIController] Zresetowano stan dla: ", entity.name)

## Wymusza na komponencie percepcji natychmiastowe rozejrzenie się po okolicy,
## pomijając czekanie na kolejną klatkę fizyki.
func force_target_scan() -> void:
	if perception:
		perception.process_perception(0.0)
		_perception_timer = perception_interval_combat if blackboard.target != null else perception_interval_idle

		# Jeśli po natychmiastowym skanie znaleźliśmy cel (gracza stojącego tuż obok), 
		# od razu uruchamiamy pościg, by uniknąć stania w miejscu jak kołek!
		if blackboard.target != null and state_machine:
			state_machine.change_state("Chase")
