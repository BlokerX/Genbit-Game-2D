extends Button

## Eksportujemy zmienną, aby przypisać scenę w Inspektorze Godota
const credits_scene = "uid://uuss2dodm1na"

## Referencja do węzła, w którym ma się pojawić scena
var main_scene_node: Node

func _pressed() -> void:
	if credits_scene == null or credits_scene == "":
		push_error("Błąd: Nie przypisano ścieżki do sceny w Inspektorze (węzeł Main)!")
		return
		
	# Wykorzystujemy Twój SceneCollectionManager do "bezpiecznego" i asynchronicznego ładowania
	var packed_scene = await SceneCollectionManager.get_packed_scene_deferred(credits_scene)
	
	if packed_scene:
		var scene_instance = packed_scene.instantiate()
			
		# Dodajemy nową (np. Grę)
		main_scene_node.add_child(scene_instance)
	else:
		push_error("Błąd: SceneCollectionManager nie mógł załadować: " + credits_scene)
