extends Node
class_name AIController

var entity: EnemyEntity
var blackboard: AIBlackboard

@export var behavior_profile: AIBehaviorProfile
@export var state_machine: AIStateMachine
@export var perception: PerceptionComponent

func initialize(owner_entity: EnemyEntity) -> void:
	entity = owner_entity
	
	# Tablicę tworzymy ZAWSZE, żeby stany nie crashowały na błędzie 'Nil'
	blackboard = AIBlackboard.new()
	blackboard.initialize(entity)
	
	if not behavior_profile:
		push_error("AIController: Brak AIBehaviorProfile! Wróg stoi w miejscu, bo nie wie jak się zachować.")
	
	if not perception:
		perception = get_node_or_null("PerceptionComponent")
	if not state_machine:
		state_machine = get_node_or_null("AIStateMachine")
	
	if perception:
		if behavior_profile:
			perception.detection_distance = behavior_profile.detection_distance
		perception.initialize(self)
	else:
		push_error("AIController: Brak węzła PerceptionComponent!")
		
	if state_machine:
		state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	if state_machine:
		state_machine.process_physics(delta)
