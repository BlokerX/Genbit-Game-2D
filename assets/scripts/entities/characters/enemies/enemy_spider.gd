extends CharacterEntity

#region Movement
@export var rotationSpeed : float = 5.0

# IDLE movement
@export var wanderRadius: float = 150.0
@export var wanderIntervalMin: float = 1.0
@export var wanderIntervalMax: float = 6.0

var wanderTimer: float = 0.0
var wanderTarget: Vector2 = Vector2.ZERO
#endregion

#region Nawigacja (pathfinding)
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var los_ray : RayCast2D = $LineOfSight
var target: Node2D
var lastKnownPos : Vector2 = Vector2.ZERO
var hasLastKnownPos : bool = false

enum State {IDLE, CHASING, SEARCHING}
var state: State = State.IDLE

## Zmienna dystansu wykrywania
@export var detectionDistance : float = 600.0
#endregion

func _ready():
	health_stats_script.health = 50
	health_stats_script.max_health = 50
	
	interaction_and_attack_stats_script.hand_damage = 10
	interaction_and_attack_stats_script.hand_cooldown = 2.0
	
	respawnVector = Vector2(1080, 720)
	
	# Health points bar initialization
	super()
	
	target = %Player

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

# Zwraca true jeżeli wykryje gracza bez obstrukcji
func has_line_of_sight() -> bool:
	if not target:
		return false
	los_ray.target_position = to_local(target.global_position)
	los_ray.force_raycast_update()
	if los_ray.is_colliding():
		# Zwróć true/false czy pierwszy collider to gracz (target)
		return los_ray.get_collider() == target
	return false

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target.position)

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)
	
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		
	# Sprawdzanie wszystkich kolizji w danej klatce
	#var is_collision_with_mob_detected = false
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("Player") and interaction_and_attack_stats_script.can_attack():
			print("Pająk atakuje gracza!")
			interaction_and_attack_stats_script.hand_attack(collider)
	
	#region Line of sight
	var in_range = target and global_position.distance_to(target.global_position) <= detectionDistance
	var can_see = in_range and has_line_of_sight()
	
	match state:
		State.IDLE:
			if can_see:
				state = State.CHASING
			# SYSTEM RUCHU W KÓŁKO DZIAŁA ALE JEST WYŁĄCZONY BO PAJĄK NIE WIE CO ZE SOBĄ ZROBIĆ
			# PRZEZ ŚLIZGANIE SIĘ W MOVEMENCIE
			#else:
				## Nigdzie nie widać gracza - poruszaj się wokoło
				#wanderTimer -= delta
				#if wanderTimer <= 0.0:
					#var random_offset = Vector2(
						#randf_range(-wanderRadius, wanderRadius),
						#randf_range(-wanderRadius, wanderRadius)
					#)
					## Wybierz losową pozycję w zakrezie wanderRadius
					#wanderTarget = global_position + random_offset
					#set_movement_target(wanderTarget)
					## Losowy czas między ruchami
					#wanderTimer = randf_range(wanderIntervalMin, wanderIntervalMax)
		State.CHASING:
			if can_see:
				lastKnownPos = target.global_position
				hasLastKnownPos = true
				set_movement_target(lastKnownPos)
			else:
				# Pająk stracił gracza z pola widzenia
				if hasLastKnownPos:
					# Pająk zna ostatnie miejsce gdzie był gracz i tam idzie
					set_movement_target(lastKnownPos)
					state = State.SEARCHING
				else:
					# Pająk nie ma zielonego pojęcia gdzie jest gracz
					state = State.IDLE
		State.SEARCHING:
			if can_see:
				# Pająk idąc w ostatnie miejsce gdzie był gracz zobaczył go znowu
				state = State.CHASING
			elif navigation_agent.is_navigation_finished():
				# Pająk dotarł do ostatniego miejsca gdzie był gracz i go nie znalazł
				hasLastKnownPos = false
				wanderTimer = randf_range(wanderIntervalMin, wanderIntervalMax)
				state = State.IDLE
	#endregion

	#region Obrót i ruch
	var should_move = (state == State.CHASING or state == State.SEARCHING) and not navigation_agent.is_navigation_finished()

	# Obraca się na bierząco w stronę gracza, ale tylko w stanie gonitwy (CHASING)
	if state == State.CHASING and can_see:
		var target_angle = global_position.angle_to_point(target.global_position)
		rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)
		
	if should_move:
		# Get the next position in the path
		var next_path_position = navigation_agent.get_next_path_position()

			# Calculate direction to next waypoint
		var direction = global_position.direction_to(next_path_position)
			
			# --- ZMIENIONO: Użycie komponentu z obliczonym wektorem kierunku do ruchu ---
		velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
			
		move_and_slide()
		return
	#endregion
