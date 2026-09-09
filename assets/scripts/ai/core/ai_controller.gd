extends Node
class_name AIController

var entity: EnemyEntity
var blackboard: AIBlackboard

@export var behavior_profile: AIBehaviorProfile
@export var perception: PerceptionComponent
@export var state_machine: AIStateMachine
@export var navigation: AINavigationController
@export var combat: AICombatController

func initialize(owner_entity: EnemyEntity) -> void:
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

func _physics_process(delta: float) -> void:
	if perception:
		perception.process_perception(delta) # DODANE: Zmysły szukają celów
	if state_machine:
		state_machine.process_physics(delta)
	if navigation:
		navigation.process_navigation(delta)
	if combat:
		combat.process_combat(delta)
