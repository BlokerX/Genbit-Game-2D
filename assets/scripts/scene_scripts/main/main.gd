extends Node

@export_group("Sceny do ładowania")
@export var game_scene : PackedScene
@export var main_menu_scene : PackedScene # Nowa wyeksportowana zmienna na Menu Główne

func _ready() -> void:
	to_main_menu()

func start_game(scene_to_remove : Node) -> void:
# Sprawdzamy czy scena została przypisana
	if game_scene:
		# Instancing of the scene
		var scene_instance = game_scene.instantiate()
		# Adds scene_instance as child of the Main node
		self.add_child(scene_instance)
		
		# Remove main_menu from SceneTree if not null
		if scene_to_remove != null :
			scene_to_remove.queue_free()
	else:
		push_error("Błąd: Nie przypisano 'game_scene' w Inspektorze!")

func to_main_menu() -> void:
	# Sprawdzamy czy scena została przypisana
	if main_menu_scene:
		# Zamiast hardcodowanej ścieżki i load(), używamy wyeksportowanej zmiennej
		var scene_instance = main_menu_scene.instantiate()
		
		# Adds main_menu as child of the Main node
		self.add_child(scene_instance)
	else:
		push_error("Błąd: Nie przypisano 'main_menu_scene' w Inspektorze!")
