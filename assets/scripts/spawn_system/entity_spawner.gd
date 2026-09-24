@tool
extends Marker2D
## Zaawansowany spawner obiektów (przeciwników, skrzyń, przedmiotów).
## Reaguje na ładowanie chunków (Open World), dystans gracza, sygnały fabularne lub komendy Reżysera.
class_name EntitySpawner

## Określa, co jest wyzwalaczem (zapalnikiem) do spawnowania obiektów.
enum TriggerMode {
	## Klasycznie: Spawnuje hurtowo Reżyser w MapRegion (idealne dla zamkniętych lochów i aren).
	DIRECTOR_ONLY,
	## Inteligentnie: Spawnuje samodzielnie, gdy WorldStreamer załaduje ten chunk na ekran (idealne dla Open World).
	ON_CHUNK_ACTIVE,
	## Na dystans: Spawnuje dopiero, gdy gracz zbliży się na określoną odległość w pikselach.
	PROXIMITY_PLAYER,
	## Fabularnie: Spawnuje po otrzymaniu hasła z EventBusa (np. otwarcie drzwi Bossa, wciśnięcie dźwigni).
	EVENT_BUS_SIGNAL
}

@export_group("Konfiguracja Spawnu")

## Zasób, z którego spawner powoła obiekt. 
## Może to być bezpośrednia scena (PackedScene) LUB Pula (EnemySpawnPool, ObjectSpawnPool, ItemLootPool).
@export var spawn_resource: Resource
## Wybierz tryb wyzwalania spawnera.
@export var trigger_mode: TriggerMode = TriggerMode.DIRECTOR_ONLY
## Jeśli fałsz, spawner jest uśpiony i nie zareaguje na żadne bodźce.
@export var is_active: bool = true

@export_group("Zarządzanie Cyklem Życia")

## Maksymalna ilość jednocześnie żyjących instancji wygenerowanych z tego spawnera.
@export var max_alive_entities: int = 1
## Czas (w sekundach) do ponownego spawnu po śmierci wygenerowanego obiektu. 
## Ustaw na 0.0, jeśli obiekt ma zginąć bezpowrotnie (pojawić się tylko raz).
@export var respawn_cooldown: float = 0.0

@export_group("Zdarzenia i Zasięgi")

## Używane TYLKO dla trybu 'PROXIMITY_PLAYER'. Określa promień wykrywania gracza w pikselach.
@export var proximity_radius: float = 500.0
## Używane TYLKO dla trybu 'EVENT_BUS_SIGNAL'. Oczekiwane hasło z EventBusa (np. 'boss_fight_started').
@export var expected_event_name: String = ""

# Wewnętrzne śledzenie stanu
var _alive_entities: Array[Node] = []
var _respawn_timer: float = 0.0
var _last_sleep_timestamp: float = 0.0
var _was_on_cooldown_when_sleeping: bool = false
var _player_ref: Node2D = null

# Flaga zapobiegająca "Fałszywym Startom" przy ładowaniu wielkiej mapy
var _initial_setup_done: bool = false

## Wywoływane, gdy węzeł wchodzi do drzewa sceny.
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	# --- NAPRAWA ZATRZYMANEGO CZASU ---
	if _was_on_cooldown_when_sleeping:
		var current_time = Time.get_unix_time_from_system()
		var time_passed_offline = current_time - _last_sleep_timestamp
		_respawn_timer += time_passed_offline
		_was_on_cooldown_when_sleeping = false
	
	# INTELIGENTNE SPAWNOWANIE (Open World): 
	# Odpala się TYLKO wtedy, gdy minęła już faza początkowa, 
	# a WorldStreamer wyciągnął ten chunk z zamrażarki i wrzucił na ekran.
	if trigger_mode == TriggerMode.ON_CHUNK_ACTIVE and _initial_setup_done:
		print("[EntitySpawner] %s: Chunk został wybudzony. Rozpoczynam spawn." % name)
		call_deferred("attempt_spawn")

func _exit_tree() -> void:
	# Zapisujemy dokładny czas (w sekundach) wylogowania chunka z pamięci
	if respawn_cooldown > 0.0 and _alive_entities.size() < max_alive_entities:
		_last_sleep_timestamp = Time.get_unix_time_from_system()
		_was_on_cooldown_when_sleeping = true
	else:
		_was_on_cooldown_when_sleeping = false

## Wywoływane, gdy węzeł jest już gotowy.
func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
		
	add_to_group("AdvancedSpawner") 
	
	if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
		print("[EntitySpawner] %s: Nasłuchuję sygnału fabularnego '%s'..." % [name, expected_event_name])
		EventBus.story_event_triggered.connect(_on_story_event)

	# --- TARCZA CLEAN CODE (False Start Prevention) ---
	# Czekamy na przetworzenie pierwszej klatki gry.
	# Daje to czas Streamerowi na przeniesienie nas do odpowiedniego chunka i ukrycie go.
	await get_tree().process_frame
	_initial_setup_done = true
	
	# Jeśli po segregacji chunków znajdujemy się w chunku, na którym WŁAŚNIE ZRESPAŁ SIĘ GRACZ (jesteśmy w drzewie),
	# spawniemy natychmiast bez czekania na zdarzenie wchodzenia do drzewa.
	if trigger_mode == TriggerMode.ON_CHUNK_ACTIVE and is_inside_tree():
		print("[EntitySpawner] %s: Gracz rozpoczął grę na moim chunku. Natychmiastowy spawn." % name)
		attempt_spawn()

## Główna pętla logiczna spawnera. Odlicza cooldowny i sprawdza dystans do gracza.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active:
		return
		
	# 1. Odliczanie do odrodzenia (jeśli ustawiono respawn_cooldown i obiekt zginął)
	if respawn_cooldown > 0.0 and _alive_entities.size() < max_alive_entities:
		_respawn_timer += delta
		if _respawn_timer >= respawn_cooldown:
			print("[EntitySpawner] %s: Cooldown respawnu minął. Próbuję przywrócić obiekt..." % name)
			attempt_spawn()
			
	# 2. Tryb zbliżeniowy (Wykrywanie gracza)
	if trigger_mode == TriggerMode.PROXIMITY_PLAYER and _alive_entities.size() < max_alive_entities:
		if not is_instance_valid(_player_ref):
			_player_ref = get_tree().get_first_node_in_group("Player")
		
		if is_instance_valid(_player_ref):
			# Szybka matematyka na potęgach (znacznie oszczędza procesor w porównaniu do klasycznego .distance_to)
			if global_position.distance_squared_to(_player_ref.global_position) <= (proximity_radius * proximity_radius):
				print("[EntitySpawner] %s: Gracz wszedł w strefę %dpx! Zaczynam spawn." % [name, proximity_radius])
				attempt_spawn()

## Główna funkcja tworząca byt. Sprawdza limit żyjących obiektów i wywołuje kreację.
func attempt_spawn() -> void:
	if not is_active or spawn_resource == null:
		return
		
	# Filtrujemy martwe obiekty z listy (np. te, które gracz już zabił/zniszczył)
	_alive_entities = _alive_entities.filter(func(entity): return is_instance_valid(entity) and not entity.is_queued_for_deletion())
	
	if _alive_entities.size() >= max_alive_entities:
		return # Mamy już komplet żyjących obiektów z tego spawnera.
		
	var spawned_node = _create_instance()
	if spawned_node:
		_finalize_spawn(spawned_node)
		_respawn_timer = 0.0

## Rozpoznaje typ podpiętego zasobu (Scena czy Pula) i tworzy instancję.
func _create_instance() -> Node:
	if spawn_resource is PackedScene:
		return spawn_resource.instantiate()
	elif spawn_resource.has_method("get_random_enemy_scene"):
		var scene = spawn_resource.get_random_enemy_scene()
		return scene.instantiate() if scene else null
	elif spawn_resource.has_method("get_random_object_scene"):
		var scene = spawn_resource.get_random_object_scene()
		return scene.instantiate() if scene else null
	elif spawn_resource is ItemLootPool:
		var entry = spawn_resource.get_random_entry()
		if entry and entry.item_data:
			var pickup = preload("res://assets/scenes/game_objects/item_pickup.tscn").instantiate()
			var unique_data = entry.item_data.duplicate(true)
			var amount = randi_range(entry.min_amount, entry.max_amount)
			pickup.item = ItemInstance.new(unique_data, amount)
			return pickup
	return null

## Nadaje obiektowi pozycję, przypina go do odpowiedniego miejsca na mapie i rejestruje w Streamerze.
func _finalize_spawn(entity: Node2D) -> void:
	entity.global_position = global_position
	
	# Priorytet 1: Jeśli Spawner jest w Chunku z WorldStreamera, przypnij do Chunka
	var parent_target = get_parent()
	
	# Priorytet 2: Jeśli jesteśmy w zamkniętym MapRegion (np. Dungeon), przypnij do folderu "Entities"
	var map_region = _get_map_region()
	if map_region:
		var entities_node = map_region.find_child("Entities", false, false)
		if entities_node:
			parent_target = entities_node
	
	parent_target.call_deferred("add_child", entity)
	_alive_entities.append(entity)
	
	print("[EntitySpawner] %s: Pomyślnie zespawnowano '%s' (Żyjące: %d/%d)." % [name, entity.name, _alive_entities.size(), max_alive_entities])
	
	# Rejestrujemy w Streamerze, jeśli akurat jest aktywny
	var streamer = get_tree().current_scene.find_child("WorldStreamer", true, false)
	if streamer and streamer.has_method("register_entity"):
		streamer.call_deferred("register_entity", entity)

## Reakcja na globalny sygnał fabularny.
func _on_story_event(event_name: String) -> void:
	if event_name == expected_event_name:
		print("[EntitySpawner] %s: Hasło '%s' potwierdzone! Wyzwalam spawn." % [name, event_name])
		attempt_spawn()

## Pomocnicze szukanie rodzica (MapRegion).
func _get_map_region() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr is MapRegion: return curr
		curr = curr.get_parent()
	return null

## Rysowanie kółek pomocniczych w Edytorze Godota (niewidoczne w grze).
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, Color.FUCHSIA, 2.0)
		draw_line(Vector2(-8, 0), Vector2(8, 0), Color.FUCHSIA, 2.0)
		draw_line(Vector2(0, -8), Vector2(0, 8), Color.FUCHSIA, 2.0)
		if trigger_mode == TriggerMode.PROXIMITY_PLAYER:
			draw_arc(Vector2.ZERO, proximity_radius, 0, TAU, 32, Color(1, 0, 1, 0.2), 1.0)
