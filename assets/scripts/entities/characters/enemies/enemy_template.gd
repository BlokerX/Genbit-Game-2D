# Modularny skrypt dla enemy
extends CharacterEntity

#region Movement variables

@export var rotationSpeed : float = 5.0

## Zmienna dystansu wykrywania
@export var detectionDistance : float = 600.0

#endregion

# Nawigacja (pathfinding)
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D

func _ready():
	#movement_universal_script = preload("res://assets/scripts/entities/movement/special_instations/enemy_movement_component.tres")
	# moveSpeed = 250
	# accelerationMultiplayer = 5.0
	# decelerationMultiplayer = 0.825
	
	#health_stats_script = preload("res://assets/scripts/entities/stats/special_instations/enemy_monitored_life_stats_component.tres")
	health_stats_script.health = 50
	health_stats_script.max_health = 50
	
	#attack_stats_script = preload("res://assets/scripts/entities/stats/special_instations/enemy_attack_stats_component.tres")
	attack_stats_script.damage = 10
	attack_stats_script.hand_cooldown = 2.0
	
	respawnVector = Vector2(1080, 720)
	
	# Health points bar initialization
	super()
	
	target = %Player
	#actor_setup.call_deferred()


func actor_setup():
	await get_tree().physics_frame
	
	set_movement_target(target.position)

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)
	
	attack_stats_script.attack_cooldown_process(delta)
		
	# Sprawdzanie wszystkich kolizji w danej klatce
	#var is_collision_with_mob_detected = false
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("Player") and attack_stats_script.can_attack():
			print("Pająk atakuje gracza!")
			attack_stats_script.attack(collider)
	
	#region Move Procedure
	
	# Sprawdzanie czy cel jest w zasięgu
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
		velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2.ZERO)
		
		move_and_slide()
		return
	
	# Get the next position in the path
	var next_path_position = navigation_agent.get_next_path_position()
	
	# Calculate direction to next waypoint
	var direction = global_position.direction_to(next_path_position)
	
	# --- ZMIENIONO: Użycie komponentu z obliczonym wektorem kierunku do ruchu ---
	velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
	
	# Move the character
	move_and_slide()
	#endregion
