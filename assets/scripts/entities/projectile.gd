extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 4.0 # Pocisk znika po 4 sekundach jeśli w nic nie trafi

var direction := Vector2.ZERO
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

# --- NAPRAWA 1: Referencja twórcy ---
var shooter: Node2D = null

func _ready():
	# Skrypt nasłuchuje "zwykłej" kolizji (np. gdy wróg wejdzie w pocisk)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta):
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return
		
	# Obliczamy wektor ruchu dla tej konkretnej klatki
	var move_vector = direction * speed * delta
	
	# --- NAPRAWA 2: Anti-Tunneling (RayCast) ---
	# Sprawdzamy fizycznie, czy na naszej drodze RUCHU jest jakaś ściana lub wróg, zanim tam w ogóle polecimy.
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vector)
	query.collision_mask = collision_mask # Używamy masek fizyki przypisanych do pocisku
	
	if shooter != null and shooter is CollisionObject2D:
		# Wykluczamy ciało samego strzelca z uderzenia promienia!
		query.exclude = [shooter.get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	if result:
		# Trafiliśmy w coś "pomiędzy" klatkami! (Ściana nie została przeskoczona)
		global_position = result.position # Teleportujemy pocisk na miejsce zderzenia
		_on_body_entered(result.collider) # Wymuszamy wywołanie ataku
	else:
		# Droga wolna, przesuwamy pocisk normalnie
		global_position += move_vector


func _on_body_entered(body: Node2D):
	# Ignorujemy kolizję z twórcą pocisku (Gracz lub Wróg nie zrani samego siebie)
	if body == shooter:
		return
		
	# --- NAPRAWA 3: Blokada podwójnego uderzenia ---
	# Jeśli dotarliśmy tutaj, odłączamy sygnał i usypiamy fizykę pocisku.
	# Dzięki temu zderzenie wywoła się tylko raz!
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	else : return
	set_deferred("monitoring", false)
	
	# Aplikowanie efektów na ofiarę (zadziała na wrogów, skrzynki, beczki itp.)
	if body.has_method("receive_effect"):
		for effect in effects_to_apply:
			body.receive_effect(effect)
			
	# Zniszcz pocisk po trafieniu w cokolwiek (wroga, drzwi lub ścianę)
	queue_free()
