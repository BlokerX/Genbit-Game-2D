@abstract
extends CharacterEntity
class_name EnemyEntity

#region Parametry wroga
## Szybkość obrotu
@export var rotationSpeed : float = 5.0
## Maksymalny dystans wykrywania entity
@export var detectionDistance : float = 600.0

@export_group("Zasięgi Ataku i Walki")

## Zasięg, w którym przeciwnik uderza (liczony od KRAWĘDZI ciał)
@export var attack_reach: float = 110.0

## Siła, z jaką potwór roztrąca przedmioty (np. 5.0 - słabiej niż gracz) ---
@export var push_force: float = 5.0

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
	# Wywołanie popychania co klatkę fizyki
	_handle_pushing()


func set_movement_target(movement_target: Vector2):
	if navigation_agent:
		navigation_agent.target_position = movement_target

func actor_setup():
	await get_tree().physics_frame
	if target:
		set_movement_target(target.position)

## Funkcja mierząca rzeczywisty dystans od krawędzi
func get_edge_distance_to_target() -> float:
	if target and is_instance_valid(target):
		var center_dist = global_position.distance_to(target.global_position)
		
		# Domyślny promień gracza, na wypadek gdyby coś poszło nie tak
		var target_radius = 20.0 
		
		# Jeśli cel to postać, pobieramy jej grubość!
		if "combat_radius" in target:
			target_radius = target.combat_radius
			
		# Sumujemy NASZ promień i promień CELU, a potem odejmujemy od dystansu
		return max(0.0, center_dist - (combat_radius + target_radius))
	return INF

# Zgeneralizowana funkcja ataku wręcz
func process_melee_attack(delta: float):
	if not interaction_and_attack_stats_script:
		return
		
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
	
	# Używamy naszej nowej funkcji mierzącej dystans Krawędź-Krawędź!
	if get_edge_distance_to_target() <= attack_reach:
		if interaction_and_attack_stats_script.can_attack():
			print(name + " atakuje gracza!")
			interaction_and_attack_stats_script.execute_attack_on_target(target)
	
# --- NOWOŚĆ: Funkcja popychania dla wrogów ---
func _handle_pushing() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Wrogowie roztrącają tylko obiekty fizyczne (upuszczony loot, dynamiczne beczki)
		if collider is RigidBody2D:
			# Używamy mniejszej siły, żeby przedmioty nie latały jak z katapulty
			collider.apply_central_impulse(-collision.get_normal() * push_force)
