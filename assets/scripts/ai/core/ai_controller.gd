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

func _physics_process(delta: float) -> void:
	if perception:
		perception.process_perception(delta) # Zmysły szukają celów
	if state_machine:
		state_machine.process_physics(delta)
	if navigation:
		navigation.process_navigation(delta)
	if combat:
		combat.process_combat(delta)
