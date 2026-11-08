extends Node
class_name AIStateMachine

@export var initial_state: AIState
## Włącz w Inspektorze, jeśli chcesz śledzić w konsoli każdą zmianę stanu AI.
## Domyślnie wyłączone, aby setki botów na dużych mapach nie blokowały wątku głównego logami print_rich.
@export var debug_log_state_changes: bool = false

var current_state: AIState
var states: Dictionary = {}

func initialize(ai_controller: AIController) -> void:
	# Pobierz wszystkie węzły-dzieci będące stanami
	for child in get_children():
		if child is AIState:
			var safe_key: String = child.name.to_lower().replace("state", "").strip_edges()
			states[safe_key] = child
			child.initialize(ai_controller)

	# Startujemy z pierwszego stanu
	if initial_state:
		change_state(initial_state.name)
	elif get_child_count() > 0:
		var first: AIState = get_child(0) as AIState
		if first:
			change_state(first.name)

func change_state(new_state_name: String) -> void:
	var state_key: String = new_state_name.to_lower().replace("state", "").strip_edges()

	if not states.has(state_key):
		push_warning("AIStateMachine: Brak stanu: " + new_state_name + " (szukany klucz: " + state_key + ")")
		return

	if current_state:
		current_state.exit()

	current_state = states[state_key]
	current_state.enter()

	if debug_log_state_changes and get_parent() != null and "entity" in get_parent() and get_parent().entity != null:
		print_rich("[color=yellow]AI (%s) zmieniło stan na: %s[/color]" % [get_parent().entity.name, current_state.name])

func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)
