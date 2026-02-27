## Połączony modularnie skrypt dla gracza ##

extends CharacterBody2D

#region Movement variables

# Wartość prędkości:
@export var moveSpeed : float = 450
@export var accelerationMultiplayer : float = 5.0
@export var decelerationMultiplayer : float = 0.825

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu:
@export var movement_universal_scirpt : MovementComponent = preload("res://assets/scripts/entities/movement/movement_component.tres")

#endregion

#region Stats variables

# GUI elements:
@export var health_points_bar : ProgressBar
@export var health_points_label : Label

@export var health_stats_script : MonitoredStatsComponent = preload("res://assets/scripts/entities/stats/special_instations/player_monitored_health_stats_component.tres")

@export var attack_stats_scirpt : AttackStatsComponent = preload("res://assets/scripts/entities/stats/special_instations/player_attack_stats_component.tres")

@export var character_sprite : Sprite2D

#endregion

func _ready():
	# Set attack parameters
	attack_stats_scirpt.attack_damage = 10
	attack_stats_scirpt.attack_cooldown = 1.0
	
	# Health points bar initialization
	health_stats_script.health_points_bar = health_points_bar
	health_stats_script.health_points_label = health_points_label

func _process(_delta):
	#region Stats GUI Procedure
	health_stats_script.update_helath_points_bar()
	#endregion

func _physics_process(delta):
	attack_stats_scirpt.attack_cooldown_process(delta)
	
	#Sprawdzanie wszystkich kolizji w danej klatce
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if Input.is_action_pressed("Attack") and collider.is_in_group("Enemy") and attack_stats_scirpt.can_attack():
			print("Gracz atakuje przeciwnika!")
			attack_stats_scirpt.attack(collider)
	
	#region Move Procedure
	
	# Movement inputs
	var horizontal := Input.get_axis("Left", "Right")
	var vertical := Input.get_axis("Up","Down")
	
	# Movement procedure
	velocity = movement_universal_scirpt.movement_procedure(delta, velocity, moveSpeed, accelerationMultiplayer, decelerationMultiplayer, Vector2(horizontal, vertical))
	
	# Set sprite orientation
	if horizontal < 0:
		if character_sprite.flip_h != false:
			character_sprite.flip_h = false
	elif horizontal > 0 :
		if character_sprite.flip_h != true:
			character_sprite.flip_h = true
	
	
	move_and_slide()
	
	# D_E_B_U_G
	#print("Monitor prędkości gracza: ", velocity)
	
	#endregion
	
	# Respawn in case of death
	if !health_stats_script.is_alive() :
		print("Player has killed successfull")
		health_stats_script.heal_completely()
		Respawn()
		return
	
	# Respawn
	if Input.is_action_just_pressed("RespawnButton") :
		Respawn()
		print("Gracz się odrodził!")
		return
	
	# Heal button
	if Input.is_action_just_pressed("HealButton") :
		health_stats_script.heal_completely()
		print("Gracz się uleczył!")
	
func Respawn():
		position = respawnVector
		velocity.x = 0
		velocity.y = 0
