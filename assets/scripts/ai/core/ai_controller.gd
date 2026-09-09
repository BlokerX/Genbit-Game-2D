extends Node
class_name AIController

var entity: EnemyEntity
var blackboard: AIBlackboard

@export var state_machine: AIStateMachine
@export var perception: PerceptionComponent

func initialize(owner_entity: EnemyEntity) -> void:
	entity = owner_entity
	
	blackboard = AIBlackboard.new()
	blackboard.initialize(entity)
	
	# AUTO-RESOLVE: Zapobiega błędom, gdy zapomnisz przeciągnąć w Inspektorze
	if not perception:
		perception = get_node_or_null("PerceptionComponent")
	if not state_machine:
		state_machine = get_node_or_null("AIStateMachine")
	
	if perception:
		perception.initialize(self)
	else:
		push_error("AIController: Brak węzła PerceptionComponent!")
		
	if state_machine:
		state_machine.initialize(self)
	else:
		push_error("AIController: Brak węzła AIStateMachine!")

func _physics_process(delta: float) -> void:
	if state_machine:
		state_machine.process_physics(delta)
