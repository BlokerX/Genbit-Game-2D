extends CharacterBody2D

# Wartość prędkości:
@export var moveSpeed : float = 500
@export var accelerationMultiplayer : float = 1.8
@export var decelerationMultiplayer : float = 0.825

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu:
@export var movement_universal_scirpt : MovementComponent = preload("res://assets/scripts/entities/movement/movement_component.tres")

func StartMessage():
	print("Załadowano skrypt odpowiadający za poruszanie się postaci!")

func _ready(): # Kiedy node pojawi się w scenie
	Respawn()
	StartMessage()
	

func _physics_process(delta):
	
	# Movement inputs
	var horizontal := Input.get_axis("Left", "Right")
	var vertical := Input.get_axis("Up","Down")
	
	# Movement procedure
	velocity = movement_universal_scirpt.movement_procedure(delta, velocity, moveSpeed, accelerationMultiplayer, decelerationMultiplayer, Vector2(horizontal, vertical))
	move_and_slide()
	print(velocity)
	
	# Respawn
	if Input.is_action_just_pressed("RespawnButton") :
		Respawn()

func Respawn():
		position = respawnVector
		velocity.x = 0
		velocity.y = 0
		
