extends Resource
class_name LootDropComponent
## Komponent odpowiedzialny za wyrzucanie przedmiotów z tabeli łupów (loot_table) po śmierci postaci.

const MAX_LOOT_SCATTER_OFFSET_PX: float = 25.0

# Konfiguracja dropu w Inspektorze
@export var item_pickup_scene: PackedScene
## Lista WSZYSTKICH przedmiotów, które mają szansę wypaść po śmierci.
@export var loot_table: Array[LootItem] = []

## Funkcja wywoływana przez encję w momencie jej śmierci.
func perform_drop(spawner: Node2D) -> void:
	if not is_instance_valid(spawner):
		push_error("LootDropComponent: Nie można wyrzucić łupu bez poprawnego obiektu spawnera!")
		return

	if loot_table.is_empty():
		return 

	if not item_pickup_scene:
		push_error("LootDropComponent: Brak przypisanej sceny item_pickup_scene!")
		return

	var spawn_parent: Node = spawner.get_parent()
	if not spawn_parent:
		return

	var spawner_origin: Vector2 = spawner.global_position

	for loot_item in loot_table:
		if loot_item == null or loot_item.item_data == null:
			continue 

		if randf() > loot_item.drop_chance:
			continue

		var pickup_instance: ItemPickup = item_pickup_scene.instantiate() as ItemPickup
		if pickup_instance == null:
			push_error("LootDropComponent: Zła scena! Przypisana scena nie posiada skryptu ItemPickup!")
			continue

		# Wzorzec Prototyp + Pyłek (SOLID): Tworzymy unikalną kopię statystyk przedmiotu
		# bez klonowania ciężkich tekstur i strumieni audio w pamięci RAM!
		var unique_loot_data: ItemData = loot_item.item_data.create_unique_copy()
		var dropped_amount: int = randi_range(loot_item.min_amount, loot_item.max_amount)
		var new_instance: ItemInstance = ItemInstance.new(unique_loot_data, dropped_amount)
		pickup_instance.item = new_instance

		var random_offset: Vector2 = Vector2(
			randf_range(-MAX_LOOT_SCATTER_OFFSET_PX, MAX_LOOT_SCATTER_OFFSET_PX),
			randf_range(-MAX_LOOT_SCATTER_OFFSET_PX, MAX_LOOT_SCATTER_OFFSET_PX)
		)
		var desired_spawn_pos: Vector2 = spawner_origin + random_offset
		var final_spawn_pos: Vector2 = ItemPickup.calculate_safe_spawn_position(
			spawner_origin, desired_spawn_pos, spawner
		)

		pickup_instance.global_position = final_spawn_pos
		spawn_parent.call_deferred("add_child", pickup_instance)
		pickup_instance.set_deferred("global_position", final_spawn_pos)
