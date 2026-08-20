extends Node2D # (lub taki typ, jaki ma Twoja scena TestMapGenerateScene)
class_name GameScene

# --- NAPRAWA KLUCZY: Używamy ścieżki tekstowej (String) zamiast PackedScene! ---
# Dzięki temu klucz początkowy na 100% dopasuje się do tego z portali.
@export_file("*.tscn") var initial_map_path: String = "res://assets/scenes/maps/level_1_test_map.tscn"

@onready var level_container: Node2D = $LevelContainer

func _ready() -> void:
	# Całkowicie opróżniamy RAM ze starych poziomów przy nowej grze
	if GlobalLevelManager.has_method("clear_level_cache"):
		GlobalLevelManager.clear_level_cache()
		
	# 1. SCENARIUSZ: Mapa jest już ręcznie wrzucona w edytorze Godota
	if level_container.get_child_count() > 0:
		var existing_map = level_container.get_child(0)
		if existing_map is Map:
			# RATUJEMY SYTUACJĘ: Ręcznie wrzuconej mapie wstrzykujemy żelazny klucz!
			existing_map.source_level_path = initial_map_path
			
	# 2. SCENARIUSZ: Kontener jest pusty, ładujemy poziom ze ścieżki
	elif initial_map_path != "":
		# Wczytujemy czysty adres pliku i tłumaczymy UID w razie potrzeby
		var resolved_path = GlobalLevelManager.get_normalized_path(initial_map_path)
		var scene_to_load = load(resolved_path) as PackedScene
		if scene_to_load:
			var map_instance = scene_to_load.instantiate()
			
			if map_instance is Map:
				map_instance.source_level_path = resolved_path
			
			level_container.add_child(map_instance)
