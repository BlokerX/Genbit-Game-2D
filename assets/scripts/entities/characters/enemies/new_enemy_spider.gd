extends EnemyEntity
class_name NewEnemySpider

#region Zmienne
@export var rotationSpeed: float = 5.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D

@export var wanderRadius: float = 150.0
@export var wanderIntervalMin: float = 1.0
@export var wanderIntervalMax: float = 6.0
var wanderTimer: float = 0.0
var wanderTarget: Vector2 = Vector2.ZERO

@export var min_stopping_distance: float = 30.0
#endregion

func _ready():
	super()
	target = get_tree().get_first_node_in_group("Player")
	if target == null:
		target = get_node_or_null("%Player")
		
	if target == null:
		push_error("BŁĄD KRYTYCZNY (Pająk): Nie znaleziono gracza w scenie!")
		
	call_deferred("actor_setup")

func actor_setup():
	if not is_inside_tree(): return
	await get_tree().physics_frame
	
	if is_inside_tree() and target:
		# Przekazanie celu do Mózgu AI (Blackboard)
		if ai_controller and ai_controller.blackboard:
			ai_controller.blackboard.target = target
		set_movement_target(target.global_position)

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

func _process(delta):
	super(delta)

func _physics_process(delta):
	# 1. Atak
	if interaction_and_attack_stats_script:
		interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.is_in_group("Player") and interaction_and_attack_stats_script.can_attack():
				print("Pająk atakuje gracza!")
				interaction_and_attack_stats_script.execute_attack_on_target(self, collider)

	# 2. Zapytanie Blackboarda: Czy mam się ruszyć?
	var should_move = false
	if ai_controller and ai_controller.blackboard:
		should_move = ai_controller.blackboard.want_to_move

	# 3. Logika poruszania
	if should_move:
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		if movement_universal_script:
			velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
		else:
			velocity = direction * 150.0
	else:
		if movement_universal_script:
			velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2.ZERO)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			
	move_and_slide()
