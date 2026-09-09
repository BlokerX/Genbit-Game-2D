extends EnemyEntity
class_name NewEnemySpider

#region Tymczasowe zmienne (Czekają na migrację do Perception i Navigation)
@export var rotationSpeed: float = 5.0
@export var detectionDistance: float = 600.0
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D
#endregion

#region Movement (Zmienne specyficzne dla Pająka)
@export var wanderRadius: float = 150.0
@export var wanderIntervalMin: float = 1.0
@export var wanderIntervalMax: float = 6.0

var wanderTimer: float = 0.0
var wanderTarget: Vector2 = Vector2.ZERO
#endregion

#region Nawigacja i stany (Spider-specific)
@onready var los_ray: RayCast2D = $LineOfSight
var lastKnownPos: Vector2 = Vector2.ZERO
var hasLastKnownPos: bool = false

@export var min_stopping_distance: float = 95.0

enum State {IDLE, CHASING, SEARCHING}
var state: State = State.IDLE
#endregion

func _ready():
	super()
	
	# Bezpieczne szukanie gracza (Fallback, jeśli %Player zawiedzie)
	target = get_tree().get_first_node_in_group("Player")
	if target == null:
		target = get_node_or_null("%Player")
		
	if target == null:
		push_error("BŁĄD KRYTYCZNY (Pająk): Nie znaleziono gracza w scenie!")
		
	# Odczekanie jednej klatki fizyki na wczytanie mapy nawigacyjnej
	call_deferred("actor_setup")

func actor_setup():
	# 1. Sprawdzamy, czy pająk jest w drzewie sceny przed pobraniem get_tree()
	if not is_inside_tree():
		return
		
	await get_tree().physics_frame
	
	# 2. Sprawdzamy ponownie, czy po odczekaniu klatki pająk nadal istnieje
	if is_inside_tree() and target:
		set_movement_target(target.global_position)

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

func has_line_of_sight() -> bool:
	if not target:
		return false
	los_ray.target_position = to_local(target.global_position)
	los_ray.force_raycast_update()
	if los_ray.is_colliding():
		return los_ray.get_collider() == target
	return false

func _process(delta):
	super(delta)

func _physics_process(delta):
	# 1. Atak z użyciem nowej funkcji z komponentu
	if interaction_and_attack_stats_script:
		interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.is_in_group("Player") and interaction_and_attack_stats_script.can_attack():
				print("Pająk atakuje gracza!")
				# TUTAJ BYŁ BŁĄD: Zmiana hand_attack na execute_attack_on_target
				interaction_and_attack_stats_script.execute_attack_on_target(self, collider)

	# 2. Widoczność i aktualizacja Stanów
	var distance_to_target = 0.0
	if target:
		distance_to_target = global_position.distance_to(target.global_position)
		
	var in_range = target and distance_to_target <= detectionDistance
	var can_see = in_range and has_line_of_sight()
	
	match state:
		State.IDLE:
			if can_see:
				state = State.CHASING
		State.CHASING:
			if can_see:
				lastKnownPos = target.global_position
				hasLastKnownPos = true
				set_movement_target(lastKnownPos)
			else:
				if hasLastKnownPos:
					set_movement_target(lastKnownPos)
					state = State.SEARCHING
				else:
					state = State.IDLE
		State.SEARCHING:
			if can_see:
				state = State.CHASING
			elif navigation_agent.is_navigation_finished():
				hasLastKnownPos = false
				wanderTimer = randf_range(wanderIntervalMin, wanderIntervalMax)
				state = State.IDLE
				
	# 3. Logika Poruszania (odporna na błędy)
	var should_move = false
	if state == State.CHASING:
		should_move = distance_to_target > min_stopping_distance
	elif state == State.SEARCHING:
		should_move = not navigation_agent.is_navigation_finished()
	
	if state == State.CHASING and can_see:
		var target_angle = global_position.angle_to_point(target.global_position)
		rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)
	
	if should_move:
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		
		# Ruch ze sprawdzaniem, czy komponent został podpięty w oknie Inspektora
		if movement_universal_script:
			velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
		else:
			velocity = direction * 150.0 # Awaryjny ruch bez komponentu
	else:
		if movement_universal_script:
			velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2.ZERO)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
	
	move_and_slide()
