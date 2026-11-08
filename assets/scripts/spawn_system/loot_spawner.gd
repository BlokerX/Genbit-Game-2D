@tool
extends BaseWorldSpawner
## Wyspecjalizowany spawner nagród. Generuje przedmioty leżące na ziemi (ItemPickup) 
## lub wstawia do świata pojemniki/skrzynie i automatycznie wypełnia je łupem.
class_name LootSpawner

const ITEM_PICKUP_SCENE: PackedScene = preload("res://assets/scenes/game_objects/item_pickup.tscn")

const MIN_CHEST_RANDOM_ROLLS: int = 2
const MAX_CHEST_RANDOM_ROLLS: int = 4
const LOOSE_LOOT_SCATTER_RANGE_PX: float = 20.0
const GIZMO_DIAMOND_HALF_SIZE: float = 16.0

@export_group("Konfiguracja Łupu")
## Zasób określający LOSOWĄ zawartość. Może to być pojedynczy ItemData lub ItemLootPool (losowa paczka wielu przedmiotów).
@export var loot_resource: Resource
## (Opcjonalne) Scena pojemnika (np. chest.tscn). Jeśli jest puste, przedmioty pojawią się bezpośrednio na ziemi.
@export var container_scene: PackedScene

@export_group("Gwarantowany Łup (100% Pewności)")
## Przedmioty, które pojawią się ZAWSZE w określonej ilości (i ew. w wybranym slocie skrzyni). 
## Idealne do zadań fabularnych lub unikalnych nagród.
@export var guaranteed_loot: Array[GuaranteedLootEntry] = []

func _init() -> void:
	# Domyślnie dla pojedynczej skrzyni ze skarbem ustawiamy limit całkowitych spawnów na 1
	max_total_spawns = 1

## Sprawdza, czy użytkownik ustawił losowy łup lub gwarantowany łup.
func _has_valid_spawn_configuration() -> bool:
	return loot_resource != null or not guaranteed_loot.is_empty()

## Buduje obiekt pojemnika LUB listę przedmiotów na ziemi, obsługując Gwarantowany i Losowy Loot (wraz z Multislotem).
func _create_spawn_nodes() -> Array[Node]:
	var instances: Array[Node] = []

	# Scenariusz A: Wstawiamy fizyczną skrzynię i wypełniamy jej StorageComponent
	if container_scene != null:
		var container: Node = container_scene.instantiate()
		var storage: StorageComponent = container.get_node_or_null("StorageComponent") as StorageComponent

		if storage != null:
			# 1. NAJPIERW Gwarantowany Loot
			for g_entry in guaranteed_loot:
				if g_entry != null and g_entry.item_data != null:
					var item_inst: ItemInstance = g_entry.create_item_instance()
					# Jeśli wymusiliśmy konkretną kratkę (i kratka istnieje w skrzyni)
					if g_entry.target_slot >= 0 and g_entry.target_slot < storage.slots.size():
						var new_slot: SlotData = SlotData.new()
						new_slot.item = item_inst
						storage.slots[g_entry.target_slot] = new_slot
					else:
						# Domyślnie - włóż w pierwsze wolne miejsce
						storage.insert_instance(item_inst)

			# 2. POTEM Dopełnienie Skrzyni Losowym Lootem (z obsługą opcji Multislot z ItemLootEntry!)
			if loot_resource is ItemLootPool:
				var pool: ItemLootPool = loot_resource as ItemLootPool
				var rolls: int = randi_range(MIN_CHEST_RANDOM_ROLLS, MAX_CHEST_RANDOM_ROLLS)
				for _i in range(rolls):
					var entry: ItemLootEntry = pool.get_random_entry()
					if entry != null and entry.item_data != null:
						var stacks_to_create: int = entry.roll_slots_count()
						for _stack_idx in range(stacks_to_create):
							storage.insert_instance(entry.create_item_instance())
			elif loot_resource is ItemData:
				storage.insert_instance(_create_default_item_instance(loot_resource as ItemData))

		instances.append(container)

	# Scenariusz B: Generujemy przedmioty luźno na ziemi (ItemPickup)
	else:
		# 1. Gwarantowany łup na ziemi
		for g_entry in guaranteed_loot:
			if g_entry != null and g_entry.item_data != null:
				var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
				pickup.item = g_entry.create_item_instance()
				instances.append(pickup)

		# 2. Losowy łup na ziemi (z obsługą liczby stacków Multislot)
		if loot_resource is ItemLootPool:
			var pool: ItemLootPool = loot_resource as ItemLootPool
			var entry: ItemLootEntry = pool.get_random_entry()
			if entry != null and entry.item_data != null:
				var stacks_count: int = entry.roll_slots_count()
				for _stack_idx in range(stacks_count):
					var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
					pickup.item = entry.create_item_instance()
					instances.append(pickup)
		elif loot_resource is ItemData:
			var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate() as ItemPickup
			pickup.item = _create_default_item_instance(loot_resource as ItemData)
			instances.append(pickup)

	return instances

## Tworzy pojedynczą instancję przedmiotu z czystego szablonu ItemData.
func _create_default_item_instance(i_data: ItemData, forced_amount: int = 1) -> ItemInstance:
	var temp_entry: ItemLootEntry = ItemLootEntry.new()
	temp_entry.item_data = i_data
	return temp_entry.create_item_instance(forced_amount)

## Oblicza pozycję spawnu: rozrzuca luźne przedmioty na boki i chroni je RayCastem przed wpadnięciem w ścianę!
func _calculate_entity_spawn_position(entity: Node2D) -> Vector2:
	if entity is RigidBody2D:
		var scatter_offset: Vector2 = Vector2(
			randf_range(-LOOSE_LOOT_SCATTER_RANGE_PX, LOOSE_LOOT_SCATTER_RANGE_PX),
			randf_range(-LOOSE_LOOT_SCATTER_RANGE_PX, LOOSE_LOOT_SCATTER_RANGE_PX)
		)
		var desired_pos: Vector2 = global_position + scatter_offset
		return ItemPickup.calculate_safe_spawn_position(global_position, desired_pos, self)
	return global_position

func _get_gizmo_color() -> Color:
	return Color.LIME_GREEN

## Rysuje zielony diament dla łupu w Edytorze Godota.
func _draw_spawner_icon() -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -GIZMO_DIAMOND_HALF_SIZE),
		Vector2(GIZMO_DIAMOND_HALF_SIZE, 0.0),
		Vector2(0.0, GIZMO_DIAMOND_HALF_SIZE),
		Vector2(-GIZMO_DIAMOND_HALF_SIZE, 0.0)
	])
	draw_polyline(pts, Color.LIME_GREEN, EDITOR_GIZMO_LINE_WIDTH)
	draw_line(pts[3], pts[0], Color.LIME_GREEN, EDITOR_GIZMO_LINE_WIDTH)
