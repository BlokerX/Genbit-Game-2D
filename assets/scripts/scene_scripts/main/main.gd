extends Node

@export_group("Ścieżki do scen (Zamiast PackedScene)")
# Wybieramy pliki .tscn z dysku, bez obciążania RAMu!
@export_file("*.tscn") var game_scene_path : String
@export_file("*.tscn") var main_menu_scene_path : String

# Trzymamy referencję do aktualnie aktywnej sceny
var current_scene : Node = null

func _ready() -> void:
	# Dodajemy Main do grupy, aby inne skrypty (jak Menu) mogły go łatwo znaleźć z każdego miejsca
	add_to_group("Main")
	to_main_menu()

# --- UNIWERSALNA FUNKCJA ZMIANY SCENY (Korzysta z Twojego menedżera!) ---
func change_scene(scene_path: String) -> void:
	if scene_path == null or scene_path == "":
		push_error("Błąd: Nie przypisano ścieżki do sceny w Inspektorze (węzeł Main)!")
		return
		
	# Wykorzystujemy Twój SceneCollectionManager do "bezpiecznego" i asynchronicznego ładowania
	var packed_scene = await SceneCollectionManager.get_packed_scene_deferred(scene_path)
	
	if packed_scene:
		var scene_instance = packed_scene.instantiate()
		
		# Płynnie usuwamy starą scenę (np. Menu)
		if current_scene != null:
			current_scene.queue_free()
			
		# Dodajemy nową (np. Grę)
		self.add_child(scene_instance)
		current_scene = scene_instance
	else:
		push_error("Błąd: SceneCollectionManager nie mógł załadować: " + scene_path)

func start_game() -> void:
	change_scene(game_scene_path)

func to_main_menu() -> void:
	change_scene(main_menu_scene_path)
