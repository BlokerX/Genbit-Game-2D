extends Resource
class_name LootDropComponent

# Konfiguracja dropu w Inspektorze
@export var item_pickup_scene: PackedScene
## Lista WSZYSTKICH przedmiotów, które mają wypaść po śmierci
@export var loot_table: Array[ItemData]
## Szansa na wyrzucenie przedmiotu.
@export_range(0.0, 1.0) var drop_chance: float = 0.25

# Funkcja wywoływana przez entity, kiedy ten umiera.
# Przekazujemy w niej 'spawner' (czyli samego entity), żeby zasób wiedział skąd wziąć pozycję.
func perform_drop(spawner: Node2D) -> void:
	# 1. Weryfikacja szansy i tabeli łupów
	if randf() > drop_chance or loot_table.is_empty():
		return 
		
	if not item_pickup_scene:
		push_error("LootDropComponent: Brak przypisanej sceny item_pickup_scene!")
		return
		
	# PĘTLA: Przechodzimy przez każdy element w liście łupów
	for item_data in loot_table:
		if item_data == null:
			continue # Ignorujemy puste pola w tablicy w Inspektorze
			
		# Tworzymy instancję przedmiotu
		var pickup_instance = item_pickup_scene.instantiate() as ItemPickup
		pickup_instance.item_data = item_data
		
		# Bierzemy pozycję ze spawnera (zabitego wroga)
		var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		pickup_instance.global_position = spawner.global_position + random_offset
		
		# Używamy get_tree() ze spawnera, bezpiecznie dodając obiekt do świata
		spawner.get_tree().current_scene.call_deferred("add_child", pickup_instance)
