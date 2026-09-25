@tool
extends Marker2D

## Wyspecjalizowany spawner nagród. Generuje przedmioty leżące na ziemi (ItemPickup) 
## lub wstawia do świata pojemniki/skrzynie i automatycznie wypełnia je łupem.
class_name LootSpawner

const ITEM_PICKUP_SCENE = preload("res://assets/scenes/game_objects/item_pickup.tscn")

enum TriggerMode {
	DIRECTOR_ONLY,
	ON_CHUNK_ACTIVE,
	PROXIMITY_PLAYER,
	EVENT_BUS_SIGNAL
}

enum RespawnCondition {
	NEVER,
	AFTER_DEATH_AND_TIME,
	TIME_ONLY,
	ON_CHUNK_REENTER,
	ON_CHUNK_REENTER_AND_TIME
}

@export_group("Konfiguracja Łupu")
## Zasób określający zawartość. Może to być pojedynczy ItemData (np. apteczka) 
## lub ItemLootPool (losowa paczka wielu przedmiotów).
@export var loot_resource: Resource
## (Opcjonalne) Scena pojemnika (np. chest.tscn). Jeśli jest puste, przedmiot pojawi się bezpośrednio na ziemi jako ItemPickup.
@export var container_scene: PackedScene

@export_group("Wyzwalacze i Aktywność")
@export var trigger_mode: TriggerMode = TriggerMode.DIRECTOR_ONLY
@export var is_active: bool = true

@export_group("Zarządzanie Cyklem Życia")
## Maksymalna ilość jednocześnie istniejących paczek/skrzyń na mapie.
@export var max_alive_entities: int = 1
## CAŁKOWITY limit użyć tego spawnera (0 = w nieskończoność). Dla jednorazowej skrzyni ustaw na 1.
@export var max_total_spawns: int = 1
## Wybierz zasadę, według której loot ma się ewentualnie odnawiać.
@export var respawn_condition: RespawnCondition = RespawnCondition.NEVER
## Czas (w sekundach) do ponownego spawnu (jeśli zasada z niego korzysta).
@export var respawn_cooldown: float = 0.0

@export_group("Zdarzenia i Zasięgi")
## Promień wykrywania gracza w pikselach (tylko dla PROXIMITY_PLAYER).
@export var proximity_radius: float = 500.0
## Oczekiwane hasło z EventBusa (tylko dla EVENT_BUS_SIGNAL).
@export var expected_event_name: String = ""

# Wewnętrzne śledzenie stanu
var _alive_entities: Array[Node] = []
var _respawn_timer: float = 0.0
var _last_sleep_timestamp: float = 0.0
var _was_on_cooldown_when_sleeping: bool = false
var _total_spawned_count: int = 0
var _initial_setup_done: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	
	if _was_on_cooldown_when_sleeping:
		var current_time = Time.get_unix_time_from_system()
		var time_passed_offline = current_time - _last_sleep_timestamp
		
		if respawn_condition == RespawnCondition.ON_CHUNK_REENTER:
			_respawn_timer = respawn_cooldown
		elif respawn_condition in [RespawnCondition.ON_CHUNK_REENTER_AND_TIME, RespawnCondition.AFTER_DEATH_AND_TIME, RespawnCondition.TIME_ONLY]:
			_respawn_timer += time_passed_offline
			
		_was_on_cooldown_when_sleeping = false

	# --- INTELIGENTNE WZNAWIANIE (Gdy chunk wraca z pamięci RAM) ---
	if _initial_setup_done:
		if trigger_mode == TriggerMode.ON_CHUNK_ACTIVE:
			call_deferred("attempt_spawn")
		# NOWOŚĆ: Nadrabianie historii z EventBus po wybudzeniu
		elif trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
			if EventBus.has_method("has_story_event_occurred") and EventBus.has_story_event_occurred(expected_event_name):
				print("[%s] Wybudzono z uśpienia. Nadrabiam zaległy event: %s" % [name, expected_event_name])
				call_deferred("attempt_spawn")

func _exit_tree() -> void:
	if respawn_cooldown > 0.0 and _alive_entities.size() < max_alive_entities:
		_last_sleep_timestamp = Time.get_unix_time_from_system()
		_was_on_cooldown_when_sleeping = true
	else:
		if respawn_condition == RespawnCondition.ON_CHUNK_REENTER and _alive_entities.size() < max_alive_entities:
			_was_on_cooldown_when_sleeping = true

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
		
	add_to_group("AdvancedSpawner") 
	if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
		EventBus.story_event_triggered.connect(_on_story_event)

	await get_tree().process_frame
	_initial_setup_done = true
	
	if trigger_mode == TriggerMode.ON_CHUNK_ACTIVE and is_inside_tree():
		attempt_spawn()
	
	# --- NOWOŚĆ: Nadrabianie historii zaraz po pierwszym wczytaniu mapy ---
	if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
		if EventBus.has_method("has_story_event_occurred") and EventBus.has_story_event_occurred(expected_event_name):
			print("[%s] Pierwsze załadowanie. Nadrabiam zaległy event: %s" % [name, expected_event_name])
			attempt_spawn()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active:
		return
		
	if respawn_condition != RespawnCondition.NEVER and respawn_condition != RespawnCondition.ON_CHUNK_REENTER:
		_alive_entities = _alive_entities.filter(func(entity): return is_instance_valid(entity) and not entity.is_queued_for_deletion())
		
		var should_count = _alive_entities.size() < max_alive_entities
		if should_count and respawn_cooldown > 0.0:
			_respawn_timer += delta
			if _respawn_timer >= respawn_cooldown and respawn_condition != RespawnCondition.ON_CHUNK_REENTER_AND_TIME:
				attempt_spawn()
	
	if trigger_mode == TriggerMode.PROXIMITY_PLAYER and _alive_entities.size() < max_alive_entities:
		var player_ref = get_tree().get_first_node_in_group("Player")
		if is_instance_valid(player_ref) and global_position.distance_squared_to(player_ref.global_position) <= (proximity_radius * proximity_radius):
			attempt_spawn()

func attempt_spawn() -> void:
	if not is_active or loot_resource == null:
		return
	if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
		return
	if respawn_condition == RespawnCondition.ON_CHUNK_REENTER_AND_TIME and _respawn_timer < respawn_cooldown and _total_spawned_count > 0:
		return

	_alive_entities = _alive_entities.filter(func(entity): return is_instance_valid(entity) and not entity.is_queued_for_deletion())
	if _alive_entities.size() >= max_alive_entities:
		return
		
	var spawned_node = _create_and_fill_instance()
	if spawned_node:
		_finalize_spawn(spawned_node)
		_respawn_timer = 0.0
		_total_spawned_count += 1
		
		if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
			is_active = false

## Buduje obiekt pojemnika (lub podnosidła) i wstrzykuje do niego loot
func _create_and_fill_instance() -> Node:
	var instance: Node = null
	
	# Scenariusz A: Wstawiamy fizyczną skrzynię i napełniamy ją
	if container_scene != null:
		instance = container_scene.instantiate()
		var storage = instance.get_node_or_null("StorageComponent")
		if storage != null:
			if loot_resource is ItemLootPool:
				var rolls = randi_range(2, 4)
				for i in range(rolls):
					var entry = loot_resource.get_random_entry()
					if entry and entry.item_data:
						storage.insert_instance(_create_item_instance(entry.item_data, entry))
			elif loot_resource is ItemData:
				storage.insert_instance(_create_item_instance(loot_resource))
	
	# Scenariusz B: Pojawia się sam przedmiot na ziemi (ItemPickup)
	else:
		instance = ITEM_PICKUP_SCENE.instantiate()
		if loot_resource is ItemLootPool:
			# Wyciąga JEDEN losowy przedmiot z puli i rzuca na ziemię
			var entry = loot_resource.get_random_entry()
			if entry and entry.item_data:
				instance.item = _create_item_instance(entry.item_data, entry)
		elif loot_resource is ItemData:
			instance.item = _create_item_instance(loot_resource)
			
	return instance

## Narzędzie generujące duszę (stan) przedmiotu.
func _create_item_instance(i_data: ItemData, entry: ItemLootEntry = null) -> ItemInstance:
	var unique_data = i_data.duplicate(true)
	var amount = 1
	if entry != null:
		amount = randi_range(entry.min_amount, entry.max_amount)
	
	var item_inst = ItemInstance.new(unique_data, amount)
	
	# Aplikacja wytrzymałości z komponentów
	var max_dur = 0
	if unique_data.components != null:
		for comp in unique_data.components:
			if comp is DurabilityComponent:
				max_dur = comp.max_durability
				break
				
	if entry != null and entry.randomize_durability and max_dur > 0:
		if entry.durability_mode == ItemLootEntry.DurabilityRollMode.PERCENTAGE:
			var dur_percent = randf_range(entry.min_durability_percent, entry.max_durability_percent)
			item_inst.state["durability"] = clampi(int(float(max_dur) * dur_percent), 1, max_dur)
		else:
			item_inst.state["durability"] = clampi(randi_range(entry.min_exact_durability, entry.max_exact_durability), 1, max_dur)
	elif max_dur > 0:
		item_inst.state["durability"] = max_dur
		
	return item_inst

func _finalize_spawn(entity: Node2D) -> void:
	entity.global_position = global_position
	var parent_target = get_parent()
	var map_region = _get_map_region()
	if map_region:
		var entities_node = map_region.find_child("Entities", false, false)
		if entities_node:
			parent_target = entities_node
			
	parent_target.call_deferred("add_child", entity)
	_alive_entities.append(entity)
	
	var streamer = get_tree().current_scene.find_child("WorldStreamer", true, false)
	if streamer and streamer.has_method("register_entity"):
		streamer.call_deferred("register_entity", entity)

func _on_story_event(event_name: String) -> void:
	if event_name == expected_event_name:
		attempt_spawn()

func _get_map_region() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr is MapRegion: return curr
		curr = curr.get_parent()
	return null

func _draw() -> void:
	if Engine.is_editor_hint():
		# Zielony diament dla łupu
		var pts = PackedVector2Array([Vector2(0, -16), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)])
		draw_polyline(pts, Color.LIME_GREEN, 2.0)
		draw_line(pts[3], pts[0], Color.LIME_GREEN, 2.0) # domknięcie
		if trigger_mode == TriggerMode.PROXIMITY_PLAYER:
			draw_arc(Vector2.ZERO, proximity_radius, 0, TAU, 32, Color(0, 1, 0, 0.2), 1.0)
