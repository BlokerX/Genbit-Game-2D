extends Area2D
class_name Door

# todo problem z przenikaniem przez pokoje z tymi samymi drzwiami (pozycja drzwi w pokoju)
signal player_entered_door(door_node)

enum State { CLOSED, OPENING, OPEN }

@export_group("Konfiguracja Drzwi")
@export var destination_door : Door = null 
@export var opening_time : float = 0.1 # Czas otwierania w sekundach

@onready var spawn_point : Marker2D = $Spawnpoint
# Zakładamy, że masz StaticBody2D jako dziecko Area2D dla fizycznej blokady
@onready var static_wall : StaticBody2D = get_node_or_null("StaticBody2D")

var current_state : State = State.CLOSED

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Na starcie drzwi są zamknięte i blokują przejście
	_update_collision()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if current_state == State.CLOSED:
			_start_opening()
		elif current_state == State.OPEN:
			_trigger_teleport()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and current_state == State.OPENING:
		# Opcjonalnie: jeśli gracz odejdzie, przerywamy otwieranie
		current_state = State.CLOSED
		print("Gracz odszedł, drzwi pozostają zamknięte.")

func _start_opening() -> void:
	current_state = State.OPENING
	print("Otwieranie drzwi... Czekaj %s sekundy." % opening_time)
	
	await get_tree().create_timer(opening_time).timeout
	
	# Sprawdzamy, czy gracz nadal jest w zasięgu (lub czy nie przerwaliśmy stanu)
	if current_state == State.OPENING:
		current_state = State.OPEN
		_update_collision()
		print("Drzwi otwarte!")
		
		# Jeśli gracz nadal stoi w drzwiach po otwarciu, teleportuj go
		for body in get_overlapping_bodies():
			if body.is_in_group("Player"):
				_trigger_teleport()
		
		# Po przejściu zamykamy drzwi
		current_state = State.CLOSED

func _update_collision() -> void:
	if static_wall:
		var wall_shape = static_wall.get_node_or_null("CollisionShape2D")
		if wall_shape:
			# Wyłączamy kolizję fizyczną (ścianę) tylko gdy drzwi są otwarte
			wall_shape.set_deferred("disabled", current_state == State.OPEN)

func _trigger_teleport() -> void:
	# Wywołujemy sygnał, który LevelManager już obsługuje
	player_entered_door.emit(self)

func get_room() -> Room:
	var current_node = self
	while current_node != null:
		if current_node is Room:
			return current_node
		current_node = current_node.get_parent()
	return null
