extends Resource
class_name LootDropComponent

# Konfiguracja dropu w Inspektorze
@export var item_pickup_scene: PackedScene
## Lista WSZYSTKICH przedmiotów, które mają wypaść po śmierci
@export var loot_table: Array[LootItem]

# Funkcja wywoływana przez entity, kiedy ten umiera.
# Przekazujemy w niej 'spawner' (czyli samego entity), żeby zasób wiedział skąd wziąć pozycję.
func perform_drop(spawner: Node2D) -> void:
	# Czy tabela lootu jest pusta?
	if loot_table.is_empty():
		return 
		
	if not item_pickup_scene:
		push_error("LootDropComponent: Brak przypisanej sceny item_pickup_scene!")
		return
	
	var spawn_parent = spawner.get_parent()
	if not spawn_parent:
		return
	
	# Przechodzimy przez każdy potencjalny loot
	for loot_item in loot_table:
		# Zabezpieczenie przed pustym polem
		if loot_item == null or loot_item.item_data == null:
			continue 
			
		# Sprawdzamy indywidualną szansę tego konkretnego przedmiotu
		if randf() > loot_item.drop_chance:
			continue
			
		var pickup_instance = item_pickup_scene.instantiate() as ItemPickup
		if pickup_instance == null:
			push_error("LootDropComponent: Zła scena! Przypisana scena nie posiada skryptu ItemPickup!")
			continue
			
		# TWORZYMY KOPIĘ SZABLONU Z TABELI LOOTU
		var unique_loot_data = loot_item.item_data.duplicate(true)
		
		# Losujemy ilość z uwzględnieniem min i max
		var dropped_amount = randi_range(loot_item.min_amount, loot_item.max_amount)
		
		# Tworzymy instancję (konstruktor od razu wstrzykuje ilość do słownika state)
		var new_instance = ItemInstance.new(unique_loot_data, dropped_amount)
		
		# Przypisujemy gotową instancję do obiektu leżącego na ziemi
		pickup_instance.item = new_instance
		
		var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		pickup_instance.global_position = spawner.global_position + random_offset
		spawn_parent.call_deferred("add_child", pickup_instance)
