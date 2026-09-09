extends Node
class_name AIStateMachine

@export var initial_state: AIState

var current_state: AIState
var states: Dictionary = {}

func initialize(ai_controller: AIController) -> void:
	# Pobierz wszystkie węzły-dzieci będące stanami
	for child in get_children():
		if child is AIState:
			# Czyścimy nazwę: usuwamy słowo "state", białe znaki i zmieniamy na małe litery
			var safe_key = child.name.to_lower().replace("state", "").strip_edges()
			states[safe_key] = child
			child.initialize(ai_controller)
			
	# Startujemy z pierwszego stanu
	if initial_state:
		change_state(initial_state.name)
	elif get_child_count() > 0:
		var first = get_child(0) as AIState
		if first:
			change_state(first.name)

func change_state(new_state_name: String) -> void:
	var state_key = new_state_name.to_lower().replace("state", "").strip_edges()
	if not states.has(state_key):
		push_warning("AIStateMachine: Brak stanu: " + new_state_name + " (szukany klucz: " + state_key + ")")
		return
		
	if current_state:
		current_state.exit()
		
	current_state = states[state_key]
	current_state.enter()
	
	# DEBUG: Zobaczysz w konsoli na żółto, że AI faktycznie pracuje!
	print_rich("[color=yellow]AI (%s) zmieniło stan na: %s[/color]" % [get_parent().entity.name, current_state.name])

func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)
