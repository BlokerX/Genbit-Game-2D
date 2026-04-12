extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 4.0 # Pocisk znika po 2 sekundach jeśli w nic nie trafi

var direction := Vector2.ZERO
var effects_to_apply: Array[Effect] = []
var _time_alive: float = 0.0

func _ready():
	# Skrypt nasłuchuje kolizji
	body_entered.connect(_on_body_entered)
	
	# Opcjonalnie: Ustawienie rotacji pocisku zgodnie z kierunkiem
	rotation = direction.angle()

func _physics_process(delta):
	# Ruch pocisku
	position += direction * speed * delta
	
	# Zniszczenie pocisku, gdy odleci za daleko / za długo
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node2D):
	# Pomijamy kolizję z graczem, który wystrzelił pocisk
	if body is PlayerCharacter:
		return
		
	# Aplikowanie efektów na ofiarę
	for effect in effects_to_apply:
		if body.has_method("receive_effect"):
			body.receive_effect(effect)
		else:
			effect.apply_effect(body)
			
	# Zniszcz pocisk po trafieniu w cokolwiek (wroga lub ścianę)
	queue_free()
