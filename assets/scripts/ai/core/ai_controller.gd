extends Node
class_name AIController

var entity: AICharacterEntity
var blackboard: AIBlackboard

@export_category("Główne Profile")
## Profil zachowania definiujący zasięg widzenia, dystans zatrzymywania się (min_stopping_distance) i prędkość obrotu.
@export var behavior_profile: AIBehaviorProfile

@export_category("Komponenty Modułowe")
## Odpowiada za zmysły (wzrok, zasięg widzenia) i wykrywanie celów (Gracza) w otoczeniu.
@export var perception: PerceptionComponent
## Mózg AI zarządzający logiką stanów i decyzyjnością (Idle, Chase, Search, etc.).
@export var state_machine: AIStateMachine
## Odpowiada za fizyczne poruszanie się po siatce NavigationRegion2D oraz wyznaczanie ścieżek.
@export var navigation: AINavigationController
## Kontroluje logikę walki, dobór odpowiedniej broni z AIInventoryController oraz moment oddania strzału.
@export var combat: AICombatController
@export var threat_assessment: ThreatAssessmentComponent

func initialize(owner_entity: AICharacterEntity) -> void:
	entity = owner_entity
	
	blackboard = AIBlackboard.new()
	blackboard.initialize(entity)
	
	if not behavior_profile:
		push_error("AIController: Brak AIBehaviorProfile!")
		
	# AUTO-RESOLVE komponentów
	if not perception: perception = get_node_or_null("PerceptionComponent")
	if not state_machine: state_machine = get_node_or_null("AIStateMachine")
	if not navigation: navigation = get_node_or_null("AINavigationController")
	if not combat: combat = get_node_or_null("AICombatController")
	
	if perception:
		if behavior_profile: perception.detection_distance = behavior_profile.detection_distance
		perception.initialize(self)
	
	if state_machine: state_machine.initialize(self)
	if navigation: navigation.initialize(self)
	if combat: combat.initialize(self)
	
	var phase_controller = get_node_or_null("AIPhaseController")
	if phase_controller:
		phase_controller.initialize(self)
	
	if not threat_assessment:
		threat_assessment = get_node_or_null("ThreatAssessmentComponent")
	if threat_assessment:
		threat_assessment.initialize(self)

func _physics_process(delta: float) -> void:
	if perception:
		perception.process_perception(delta) # Zmysły szukają celów
	if threat_assessment:
		threat_assessment.process_threats(delta)
	if state_machine:
		state_machine.process_physics(delta)
	if navigation:
		navigation.process_navigation(delta)
	if combat:
		combat.process_combat(delta)

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
		# Zakładamy, że kluczem bazowego stanu w Twojej maszynie jest "idle"
		state_machine.change_state("Idle")
		
	print("[AIController] Zresetowano stan dla: ", entity.name)

## Wymusza na komponencie percepcji natychmiastowe rozejrzenie się po okolicy,
## pomijając czekanie na kolejną klatkę fizyki.
func force_target_scan() -> void:
	if perception:
		# Przekazujemy deltę 0.0, ponieważ zależy nam wyłącznie na natychmiastowym 
		# zaktualizowaniu 'blackboard.target', a nie na płynnym odliczaniu czasu.
		perception.process_perception(0.0)
		
		# Jeśli po natychmiastowym skanie znaleźliśmy cel (gracza stojącego tuż obok), 
		# od razu uruchamiamy pościg, by uniknąć stania w miejscu jak kołek.
		if blackboard.target != null and state_machine:
			state_machine.change_state("Chase")
