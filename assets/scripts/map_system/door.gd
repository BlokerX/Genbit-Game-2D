extends Area2D
class_name Door

# todo problem z przenikaniem przez pokoje z tymi samymi drzwiami (pozycja drzwi w pokoju)
signal player_entered_door(door_node)

enum State { CLOSED, OPENING, OPEN }

## Kierunek drzwi na wirtualnej siatce
enum Direction { NONE, UP, DOWN, LEFT, RIGHT }
@export var door_direction: Direction = Direction.NONE

# --- STAŁE ---
const PLAYER_GROUP = "Player"

@export_group("Konfiguracja Drzwi")
## Wymagane przypisanie w Inspektorze (inaczej drzwi nie zadziałają!)
@export var destination_door : Door = null 
@export var opening_time : float = 0.1 # Czas otwierania w sekundach
@export var is_door_visible : bool = true

@onready var spawn_point : Marker2D = $Spawnpoint
@onready var door_sprite : Sprite2D = $Sprite2D

var current_state : State = State.CLOSED

## Blokada drzwi (if is true it doesn't work)
var is_locked : bool = false

func _ready() -> void:
	door_sprite.visible = is_door_visible
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Jeśli drzwi są zablokowane (trwa walka), ignorujemy wejście gracza
	if is_locked:
		return
	
	if body.is_in_group(PLAYER_GROUP):
		if current_state == State.CLOSED:
			_start_opening()
		elif current_state == State.OPEN:
			_trigger_teleport()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP) and current_state == State.OPENING:
		# Opcjonalnie: jeśli gracz odejdzie, przerywamy otwieranie
		current_state = State.CLOSED
		print("Gracz odszedł, drzwi pozostają zamknięte.")

func _start_opening() -> void:
	current_state = State.OPENING
	print("Otwieranie drzwi... Czekaj %s sekundy." % opening_time)
	
	# Używamy Tweena zamiast globalnego timera. Tween przypina się do tego 
	# konkretnego węzła. Jeśli węzeł zostanie usunięty z pamięci, Tween sam zginie.
	var tween = create_tween()
	tween.tween_interval(opening_time)
	await tween.finished
	
	# Zabezpieczenie: Sprawdzamy, czy po odczekaniu drzwi nadal są w aktywnym drzewie 
	# (bo Map mógł w międzyczasie usunąć pokój przez remove_child)
	if not is_inside_tree():
		current_state = State.CLOSED
		return
	
	# Sprawdzamy, czy gracz nadal jest w zasięgu (lub czy nie przerwaliśmy stanu)
	if current_state == State.OPENING:
		current_state = State.OPEN
		print("Drzwi otwarte!")
		
		# Jeśli gracz nadal stoi w drzwiach po otwarciu, teleportuj go
		for body in get_overlapping_bodies():
			if body.is_in_group(PLAYER_GROUP):
				_trigger_teleport()
		
		# Po przejściu zamykamy drzwi
		current_state = State.CLOSED

#region Lock metods

func lock_door() -> void:
	is_locked = true
	current_state = State.CLOSED # Upewniamy się, że drzwi są w stanie zamkniętym

func unlock_door() -> void:
	is_locked = false

#endregion

func _trigger_teleport() -> void:
	# Bezpieczne sprawdzenie, czy programista na pewno podpiął drzwi w edytorze.
	if destination_door == null:
		push_error("BŁĄD KRYTYCZNY: Drzwi '%s' (Pokój: %s) nie mają przypisanego 'destination_door' w Inspektorze!" % [name, str(get_room().name) if get_room() else "Nieznany"])
		return
	
	# Wywołujemy sygnał, który Map już obsługuje
	player_entered_door.emit(self)

func get_room() -> Room:
	var current_node = self
	while current_node != null:
		if current_node is Room:
			return current_node
		current_node = current_node.get_parent()
	return null

## Funkcja do Auto-Linkera
func get_direction_offset() -> Vector2i:
	match door_direction:
		Direction.UP: return Vector2i(0, -1)
		Direction.DOWN: return Vector2i(0, 1)
		Direction.LEFT: return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
	return Vector2i.ZERO
	# todo rozdzielić kierunki, null od wpisany już
