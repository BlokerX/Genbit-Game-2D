# ---
# ---
# ---
# ---
# ---
# Wzór jak łączyć z parentem
extends EnemyEntity 

func _ready():
	# Możesz tutaj ustawić unikalne statystyki dla tego konkretnego typu wroga
	health_stats_script.health = 50
	health_stats_script.max_health = 50
	
	interaction_and_attack_stats_script.hand_damage = 10
	interaction_and_attack_stats_script.hand_cooldown = 2.0
	
	respawnVector = Vector2(1080, 720)
	
	# Pamiętaj o wywołaniu super(), które zainicjuje UI i znajdzie gracza w EnemyEntity
	super()

func _process(delta):
	super(delta)

func _physics_process(delta):
	# Zamiast powielać kod, wywołujemy naszą nową funkcję z EnemyEntity
	process_melee_attack(delta)
	
	#region Move Procedure
	var is_target_in_range = false
	if target:
		is_target_in_range = global_position.distance_to(target.global_position) <= detectionDistance
		
	if target and is_target_in_range:
		set_movement_target(target.global_position)
		# Smoothly rotate towards the target
		var target_angle = global_position.angle_to_point(target.global_position)
		rotation = lerp_angle(rotation, target_angle, rotationSpeed * delta)
	
	if navigation_agent.is_navigation_finished() or not is_target_in_range:
		velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2.ZERO)
		move_and_slide()
		return
	
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	
	velocity = movement_universal_script.movement_procedure(delta, velocity, direction)
	move_and_slide()
	#endregion
