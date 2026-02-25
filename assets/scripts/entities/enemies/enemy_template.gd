extends CharacterBody2D

#region Movement variables

# Wartość prędkości:
@export var moveSpeed : float = 150
@export var accelerationMultiplayer : float = 5.0
@export var decelerationMultiplayer : float = 0.825
@export var rotationSpeed : float = 5.0

# --- DODANO: Zmienna dystansu wykrywania ---
@export var detectionDistance : float = 500.0

@export var respawnVector := Vector2(1080, 720)

# Komponent ruchu:
@export var movement_universal_scirpt : MovementComponent = preload("res://assets/scripts/entities/movement/movement_component.tres")

#endregion

#region Stats variables

# Defaultowy stats component, póki co
@export var stats_script : StatsComponent = preload("res://assets/scripts/entities/stats/stats_component.tres")

#endregion

# Nawigacja (pathfinding)
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D

func _ready():
	stats_script.health = 50
	stats_script.max_health = 50
	target = %Player
	#actor_setup.call_deferred()


func actor_setup():
	await get_tree().physics_frame
	
	set_movement_target(target.position)

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

func _physics_process(delta):
	#region Move Procedure
	
	# --- DODANO: Sprawdzanie czy cel jest w zasięgu ---
	var is_target_in_range = false
	if target:
		is_target_in_range = global_position.distance_to(target.global_position) <= detectionDistance
		
	# Update target position if we have a target AND is in range
	if target and is_target_in_range:
		set_movement_target(target.global_position)
	
	# Handle rotation towards target AND is in range
	if target and is_target_in_range:
		# Calculate the angle to the target
		var target_angle = global_position.angle_to_point(target.global_position)
		# Smoothly rotate towards the target
		rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)
	
	# Don't move if navigation is finished OR target is out of range
	if navigation_agent.is_navigation_finished() or not is_target_in_range:
		
		# Apply deceleration when stopping
		# old # velocity = velocity * decelerationMultiplayer
		velocity = movement_universal_scirpt.movement_procedure(delta, velocity, moveSpeed, accelerationMultiplayer, decelerationMultiplayer, Vector2.ZERO)
		
		move_and_slide()
		return
	
	# Get the next position in the path
	var next_path_position = navigation_agent.get_next_path_position()
	
	# Calculate direction to next waypoint
	var direction = global_position.direction_to(next_path_position)
	
	# --- ZMIENIONO: Użycie komponentu z obliczonym wektorem kierunku do ruchu ---
	velocity = movement_universal_scirpt.movement_procedure(delta, velocity, moveSpeed, accelerationMultiplayer, decelerationMultiplayer, direction)
	
	# Move the character
	move_and_slide()
	#endregion
