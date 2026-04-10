@abstract
extends CharacterEntity
class_name EnemyEntity

#region Parametry wroga
## Szybkość obrotu
@export var rotationSpeed : float = 5.0
## Maksymalny dystans wykrywania entity
@export var detectionDistance : float = 600.0
#endregion

#region Nawigacja i wskaźnik na wroga
## Nawigacja
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
## Wskaźnik na aktualnego wroga
var target: Node2D
#endregion


func _ready():
	# Wywołanie inicjalizacji UI i statystyk z CharacterEntity
	super()
	
	# Przypisanie gracza jako domyślnego celu
	target = %Player

func _process(_delta):
	super(_delta)

func _physics_process(_delta):
	super(_delta)


func set_movement_target(movement_target: Vector2):
	if navigation_agent:
		navigation_agent.target_position = movement_target

func actor_setup():
	await get_tree().physics_frame
	if target:
		set_movement_target(target.position)


# Zgeneralizowana funkcja ataku wręcz – do wywoływania w _physics_process dziecka
func process_melee_attack(delta: float):
	if not interaction_and_attack_stats_script:
		return
		
	# Procesowanie cooldownu ataku
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		
	# Sprawdzanie wszystkich kolizji w danej klatce
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Jeśli przeciwnik zderzył się z graczem i może zaatakować
		if collider and collider.is_in_group("Player") and interaction_and_attack_stats_script.can_attack():
			print(name + " atakuje gracza!")
			interaction_and_attack_stats_script.hand_attack(collider)
