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

@export var stats_script : MonitoredStatsComponent = preload("res://assets/scripts/entities/stats/special_instations/player_monitored_stats_component.tres")

@export var character_sprite : Sprite2D

#endregion

func _ready():
	# Health points bar initialization
	stats_script.health_points_bar = health_points_bar
	stats_script.health_points_label = health_points_label

func _process(_delta):
	#region Stats GUI Procedure
	stats_script.update_helath_points_bar()
	#endregion

func _physics_process(delta):
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
	
	# Respawn
	if Input.is_action_just_pressed("RespawnButton") :
		Respawn()
	
	# Throw damage // test version
	# todo -> ujednolicić wzór na detekcję kolizji
	#Sprawdzanie wszystkich kolizji w danej klatce
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("Enemy"):
			print("Gracz wpadł na przeciwnika!")
			if Input.is_action_pressed("Attack"):
				collider.stats_script.take_damage(1)
	
	# Respawn in case of death
	if !stats_script.is_alive() :
		print("Player has killed successfull")
		stats_script.heal_completely()
		Respawn()
	
func Respawn():
		position = respawnVector
		velocity.x = 0
		velocity.y = 0
