extends Area2D
class_name LevelEntrance

@export_group("Konfiguracja Przejścia")
## Moje ID (np. "dungeon_stairs_up", "surface_portal"). Musi być unikalne na mapie!
@export var my_entrance_id: String = "start_point"

## Ścieżka tekstowa do pliku mapy (CAŁKOWICIE ELIMINUJE CYKLICZNOŚĆ!)
@export_file("*.tscn") var target_level_path: String

## ID wejścia w docelowej mapie, z którego ma wyjść gracz
@export var target_entrance_id: String = "start_point"

## Punkt, w którym pojawi się gracz wychodząc z tego przejścia (Marker2D)
@onready var spawn_point: Marker2D = $Spawnpoint

## Blokada, żeby schody nie odpalały się wielokrotnie na sekundę
var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Jeśli już raz aktywowaliśmy przejście, ignorujemy kolejne wejścia
	if has_triggered:
		return
		
	if body.is_in_group("Player"):
		if target_level_path != "":
			has_triggered = true # Zamykamy bramkę!
			print("Wchodzę do nowego poziomu ze ścieżki: ", target_level_path)
			GlobalLevelManager.change_level_by_path(target_level_path, target_entrance_id)
		else:
			push_warning("Brak przypisanej ścieżki target_level_path w przejściu!")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		has_triggered = false # Odblokowujemy portal, gdy gracz się oddali
