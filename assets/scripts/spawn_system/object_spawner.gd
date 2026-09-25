@tool
extends Marker2D

## Zaawansowany spawner obiektów fizycznych, przeszkód, pułapek i min.
## Reaguje na te same bodźce co spawner przeciwników i pozwala na pełne zarządzanie cyklem życia.
class_name ObjectSpawner

## Określa, co jest wyzwalaczem (zapalnikiem) do spawnowania obiektów.
enum TriggerMode {
	DIRECTOR_ONLY,
	ON_CHUNK_ACTIVE,
	PROXIMITY_PLAYER,
	EVENT_BUS_SIGNAL
}

## W jakich warunkach spawner ma odrodzić obiekt po jego zniszczeniu?
enum RespawnCondition {
	NEVER,
	AFTER_DEATH_AND_TIME,
	TIME_ONLY,
	ON_CHUNK_REENTER,
	ON_CHUNK_REENTER_AND_TIME
}

@export_group("Konfiguracja Obiektu")
## Zasób określający co ma się pojawić. 
## Przeciągnij tutaj konkretną scenę (PackedScene) LUB pulę obiektów (ObjectSpawnPool).
@export var spawn_resource: Resource
## Jeśli postawiony obiekt należy do klasy PlacedObject (np. mina, postawiona skrzynka), 
## możesz tu przypisać ItemData. Obiekt zapamięta ten przedmiot i wyrzuci go po zniszczeniu/podniesieniu.
@export var drop_item_data: ItemData

@export_group("Wyzwalacze i Aktywność")
@export var trigger_mode: TriggerMode = TriggerMode.DIRECTOR_ONLY
@export var is_active: bool = true

@export_group("Zarządzanie Cyklem Życia")
## Maksymalna ilość jednocześnie żyjących (niezniszczonych) obiektów z tego spawnera.
@export var max_alive_entities: int = 1
## CAŁKOWITY limit użyć tego spawnera w historii gry (0 = nieskończoność). Np. 1 = pojawi się tylko raz na zawsze.
@export var max_total_spawns: int = 0
## Wybierz zasadę, według której obiekty powracają do gry.
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
	if not is_active or spawn_resource == null:
		return
	if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
		return
	if respawn_condition == RespawnCondition.ON_CHUNK_REENTER_AND_TIME and _respawn_timer < respawn_cooldown and _total_spawned_count > 0:
		return

	_alive_entities = _alive_entities.filter(func(entity): return is_instance_valid(entity) and not entity.is_queued_for_deletion())
	if _alive_entities.size() >= max_alive_entities:
		return
		
	var spawned_node = _create_instance()
	if spawned_node:
		_inject_placed_object_data(spawned_node)
		_finalize_spawn(spawned_node)
		_respawn_timer = 0.0
		_total_spawned_count += 1
		
		if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
			is_active = false

func _create_instance() -> Node:
	if spawn_resource is PackedScene:
		return spawn_resource.instantiate()
	elif spawn_resource is ObjectSpawnPool:
		var scene = spawn_resource.get_random_object_scene()
		return scene.instantiate() if scene else null
	return null

## Wstrzykuje duszę przedmiotu do obiektu typu PlacedObject (aby wypadł po uderzeniu)
func _inject_placed_object_data(instance: Node) -> void:
	if instance is PlacedObject and drop_item_data != null:
		var unique_data = drop_item_data.duplicate(true)
		var item_instance = ItemInstance.new(unique_data, 1)
		# Aplikacja wytrzymałości z komponentów
		if unique_data.components != null:
			for comp in unique_data.components:
				if comp is DurabilityComponent:
					item_instance.state["durability"] = comp.max_durability
					break
		instance.saved_item_instance = item_instance

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
		# Żółty kwadrat dla obiektów fizycznych
		draw_rect(Rect2(-12, -12, 24, 24), Color.YELLOW, false, 2.0)
		draw_line(Vector2(-12, -12), Vector2(12, 12), Color.YELLOW, 2.0)
		draw_line(Vector2(-12, 12), Vector2(12, -12), Color.YELLOW, 2.0)
		if trigger_mode == TriggerMode.PROXIMITY_PLAYER:
			draw_arc(Vector2.ZERO, proximity_radius, 0, TAU, 32, Color(1, 1, 0, 0.2), 1.0)
