extends Area2D
class_name LevelEntrance

@export_group("Konfiguracja Przejścia")
## Moje ID (np. "dungeon_stairs_up", "surface_portal"). Musi być unikalne na mapie!
@export var my_entrance_id: String = "start_point"

## Ścieżka tekstowa do pliku mapy (Bezpieczna, bez cykliczności)
@export_file("*.tscn") var target_level_path: String

## ID wejścia w docelowej mapie, z którego ma wyjść gracz
@export var target_entrance_id: String = "start_point"

## Punkt, w którym pojawi się gracz wychodząc z tego przejścia (Marker2D)
@onready var spawn_point: Marker2D = $Spawnpoint

## Domyślnie false – portal jest w pełni dostępny, gdy podchodzisz do niego z zewnątrz
var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# INTELIGENTNY START:
	# Jeśli GlobalLevelManager ma zapisane ID, które pasuje do mojego ID,
	# oznacza to, że gracz pojawił się WŁAŚNIE TUTAJ po teleportacji.
	# Blokujemy wtedy portal na start, żeby uniknąć pętli!
	if GlobalLevelManager.target_entrance_id == my_entrance_id:
		has_triggered = true
	else:
		has_triggered = false

func _on_body_entered(body: Node2D) -> void:
	# Jeśli portal jest zablokowany, ignorujemy wejście
	if has_triggered:
		return
		
	if body.is_in_group("Player"):
		if target_level_path != "":
			has_triggered = true # Zamykamy bramkę na czas zmiany poziomu
			print("Wchodzę do nowego poziomu ze ścieżki: ", target_level_path)
			GlobalLevelManager.change_level_by_path(target_level_path, target_entrance_id)
		else:
			push_warning("Brak przypisanej ścieżki target_level_path w przejściu!")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# Gdy gracz wyjdzie z obszaru drzwi, odblokowujemy portal do ponownego użytku
		has_triggered = false
