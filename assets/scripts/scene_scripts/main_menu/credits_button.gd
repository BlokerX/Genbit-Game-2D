extends Button

## Eksportujemy zmienną, aby przypisać scenę w Inspektorze Godota
@export var credits_scene: PackedScene

## Referencja do węzła, w którym ma się pojawić scena
var main_scene_node: Node

func _pressed() -> void:
	# Sprawdzamy bezpiecznie, czy scena została przypisana w Inspektorze
	if credits_scene:
		var scene_instance = credits_scene.instantiate()
		
		# Sprawdzamy, czy mamy gdzie dodać instancję
		if main_scene_node:
			main_scene_node.add_child(scene_instance)
		else:
			# Jeśli nie przypisano main_scene_node, dodajemy do rodzica przycisku lub Roota
			get_tree().current_scene.add_child(scene_instance)
	else:
		push_error("Błąd: Nie przypisano 'credits_scene' w Inspektorze dla przycisku: ", name)
