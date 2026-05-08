extends Area2D
class_name Door

signal player_entered_door(door_node)

@export_group("Konfiguracja Drzwi")
# Przypisujemy TYLKO drzwi docelowe
@export var destination_door : Door = null 

@onready var spawn_point : Marker2D = $Spawnpoint

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Gracz wszedł w drzwi!")
		player_entered_door.emit(self)

# NOWA FUNKCJA: Szuka pokoju, w którym są te drzwi
func get_room() -> Room:
	var current_node = self
	while current_node != null:
		if current_node is Room:
			return current_node
		current_node = current_node.get_parent() # Idziemy węzeł wyżej w drzewie
	
	return null # Zwraca null, jeśli drzwi nie są wewnątrz żadnego pokoju
