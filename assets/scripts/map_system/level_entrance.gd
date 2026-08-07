extends Area2D
class_name LevelEntrance

@export_group("Konfiguracja Przejścia")
## Moje ID (np. "dungeon_stairs_up", "surface_portal"). Musi być unikalne na mapie!
@export var my_entrance_id: String = "start_point"

## Scena mapy, do której prowadzi to przejście
@export var target_level: PackedScene

## ID wejścia w docelowej mapie, z którego ma wyjść gracz
@export var target_entrance_id: String = "start_point"

## Punkt, w którym pojawi się gracz wychodząc z tego przejścia (Marker2D)
@onready var spawn_point: Marker2D = $Spawnpoint

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if target_level != null:
			print("Wchodzę do nowego poziomu! Cel: ", target_entrance_id)
			GlobalLevelManager.change_level(target_level, target_entrance_id)
		else:
			push_warning("Brak przypisanej sceny target_level w przejściu!")
