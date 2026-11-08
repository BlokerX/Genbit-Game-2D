extends Area2D
class_name Door

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
const PLAYER_GROUP: String = "Player"
## Próg czasu otwierania (w sekundach), poniżej którego otwarcie uznawane jest za natychmiastowe.
## Zapobiega nakładaniu się dwóch dźwięków (opening + transition) w odstępie 0.1s ("pik-pik").
const INSTANT_OPEN_THRESHOLD_SEC: float = 0.25

@export_group("Oprawa dźwiękowa")
## Dźwięk odtwarzany, gdy drzwi zaczynają się otwierać.
@export var opening_feedback: FeedbackCue = preload(
	"res://assets/data/feedback/environment/door_open.tres"
)
## Dźwięk przejścia gracza przez otwarte drzwi.
@export var transition_feedback: FeedbackCue = preload(
	"res://assets/data/feedback/environment/door_transition.tres"
)
## Jeśli false (domyślnie), przy błyskawicznym otwieraniu (np. 0.1s) gra odtworzy tylko jeden dźwięk przejścia,
## eliminując podwójny efekt "pik-pik". Włącz, jeśli masz długą animację otwierania bramy i chcesz obu dźwięków.
@export var play_both_sounds_on_fast_open: bool = false

signal player_entered_door(door_node : Node)

enum State { CLOSED, OPENING, OPEN }

## Kierunek drzwi na wirtualnej siatce
enum Direction { NONE, UP, DOWN, LEFT, RIGHT }
@export var door_direction: Direction = Direction.NONE

@export_group("Konfiguracja Drzwi")
## Wymagane przypisanie w Inspektorze lub przez Auto-Linker (inaczej drzwi nie zadziałają).
@export var destination_door : Door = null 
@export var opening_time : float = 0.1 # Czas otwierania w sekundach
@export var is_door_visible : bool = true
## Dedykowana tekstura (ustawiana przez auto-generator lub w Inspektorze)
@export var door_texture: Texture2D = null

@onready var spawn_point : Marker2D = $Spawnpoint
@onready var door_sprite : Sprite2D = $Sprite2D

var current_state : State = State.CLOSED
## Blokada chroniąca drzwi docelowe przed natychmiastowym ponownym otwarciem, gdy gracz pojawia się w nowym pokoju.
var _ignore_arriving_player : bool = false

@export_group("Blokady (Locks)")
## Główna kłódka. Włącz w Inspektorze, aby drzwi były zamknięte np. na klucz, dźwignię lub questa.
@export var is_mechanically_locked : bool = false

## Wewnętrzna blokada. Steruje nią TYLKO system pokoju (MapRegion) podczas walki.
var is_combat_locked : bool = false

func _ready() -> void:
	door_sprite.visible = is_door_visible

	# Nadpisywanie tekstury, jeśli została przekazana
	if door_texture != null:
		door_sprite.texture = door_texture

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

## Oznacza te drzwi jako punkt wyjścia, w którym właśnie pojawił się gracz po przejściu z sąsiedniego pokoju.
## Zapobiega fałszywemu odegraniu dźwięku otwierania drzwi za plecami gracza.
func register_player_arrival() -> void:
	_ignore_arriving_player = true
	current_state = State.CLOSED
	# Jeśli gracz został postawiony na tyle daleko od drzwi, że w ogóle nie dotyka ich Area2D,
	# zdejmujemy blokadę w kolejnej klatce fizyki.
	call_deferred("_release_arrival_lock_if_not_overlapping")

func _release_arrival_lock_if_not_overlapping() -> void:
	if not is_inside_tree():
		_ignore_arriving_player = false
		return
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body.is_in_group(PLAYER_GROUP):
			return
	_ignore_arriving_player = false

func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body) or not body.is_in_group(PLAYER_GROUP):
		return

	# Ignorujemy wejście, jeśli gracz właśnie wyszedł z tych drzwi po teleportacji lub się odradza
	if _ignore_arriving_player or body.get("is_respawning") == true:
		return

	# Jeśli drzwi są zablokowane (trwa walka lub kłódka fabularna), ignorujemy wejście gracza
	if is_mechanically_locked or is_combat_locked:
		return

	if current_state == State.CLOSED:
		_start_opening()
	elif current_state == State.OPEN:
		_trigger_teleport()

func _on_body_exited(body: Node2D) -> void:
	if not is_instance_valid(body) or not body.is_in_group(PLAYER_GROUP):
		return

	# Gdy gracz opuści strefę drzwi docelowych, odblokowujemy je do normalnego użytku
	if _ignore_arriving_player:
		_ignore_arriving_player = false
		return

	if current_state == State.OPENING:
		# Jeśli gracz odejdzie w trakcie otwierania, przerywamy otwieranie
		current_state = State.CLOSED
		print("Gracz odszedł, drzwi pozostają zamknięte.")

func _start_opening() -> void:
	current_state = State.OPENING
	print("Otwieranie drzwi... Czekaj %s sekundy." % opening_time)

	# NAPRAWA PODWÓJNEGO DŹWIĘKU ("pik-pik"):
	# Odtwarzamy dźwięk otwierania tylko wtedy, gdy czas otwierania jest zauważalny (> 0.25s),
	# lub gdy nie ma dźwięku przejścia (transition_feedback), albo gdy wymuszono oba dźwięki w Inspektorze.
	var should_play_open_sound: bool = (
		play_both_sounds_on_fast_open
		or transition_feedback == null
		or opening_time > INSTANT_OPEN_THRESHOLD_SEC
	)
	if should_play_open_sound:
		_play_feedback(opening_feedback)

	# Używamy Tweena przypiętego do tego konkretnego węzła
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(0.01, opening_time))
	await tween.finished

	# Zabezpieczenie: Sprawdzamy, czy po odczekaniu drzwi nadal są w aktywnym drzewie
	if not is_instance_valid(self) or not is_inside_tree():
		current_state = State.CLOSED
		return

	# Sprawdzamy, czy gracz nadal jest w zasięgu (lub czy nie przerwaliśmy stanu)
	if current_state == State.OPENING:
		current_state = State.OPEN
		print("Drzwi otwarte!")
		# Jeśli gracz nadal stoi w drzwiach po otwarciu, teleportuj go
		for body in get_overlapping_bodies():
			if is_instance_valid(body) and body.is_in_group(PLAYER_GROUP):
				_trigger_teleport()
				break
		# Po przejściu zamykamy drzwi
		current_state = State.CLOSED

#region Lock methods
## --- BLOKADY WALKI (Sterowane przez system pokoju) ---
func combat_lock_door() -> void:
	is_combat_locked = true
	current_state = State.CLOSED

func unlock_combat_door() -> void:
	is_combat_locked = false

## --- BLOKADY MECHANICZNE/FABULARNE (Klucze, dźwignie, questy) ---
func mechanically_lock_door() -> void:
	is_mechanically_locked = true
	current_state = State.CLOSED

func mechanically_unlock_door() -> void:
	is_mechanically_locked = false

## --- WYMUSZENIE OTWARCIA (Np. po odebraniu sygnału ze StoryEventReceiver) ---
func force_open() -> void:
	mechanically_unlock_door() # 1. Zdejmujemy kłódkę fabularną
	unlock_combat_door()       # 2. Zdejmujemy kraty z walki (na wszelki wypadek)

	if current_state == State.CLOSED:
		_start_opening()
#endregion

func _trigger_teleport() -> void:
	# Bezpieczne sprawdzenie, czy programista na pewno podpiął drzwi w edytorze.
	if destination_door == null:
		var region_name: String = str(get_map_region().name) if get_map_region() != null else "Nieznany"
		push_error("BŁĄD KRYTYCZNY: Drzwi '%s' (Pokój: %s) nie mają przypisanego 'destination_door' w Inspektorze!" % [name, region_name])
		return

	# Odtwarzamy dźwięk przejścia (lub opening_feedback jako fallback, jeśli transition_feedback jest pusty)
	if transition_feedback != null:
		_play_feedback(transition_feedback)
	elif opening_time <= INSTANT_OPEN_THRESHOLD_SEC and not play_both_sounds_on_fast_open:
		_play_feedback(opening_feedback)

	player_entered_door.emit(self)

func _play_feedback(cue: FeedbackCue) -> void:
	if cue != null:
		GameFeedback.play_cue(cue, null, global_position, self)

func get_map_region() -> MapRegion:
	var current_node: Node = self
	while current_node != null:
		if current_node is MapRegion:
			return current_node as MapRegion
		current_node = current_node.get_parent()
	return null

## Funkcja do Auto-Linkera zwracająca wektor kierunku na siatce pokoi.
func get_direction_offset() -> Vector2i:
	match door_direction:
		Direction.UP: return Vector2i(0, -1)
		Direction.DOWN: return Vector2i(0, 1)
		Direction.LEFT: return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
	return Vector2i.ZERO
