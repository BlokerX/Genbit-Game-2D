@tool
extends Marker2D
## Abstrakcyjna klasa bazowa dla wszystkich zaawansowanych spawnerów w grze (EntitySpawner, LootSpawner, ObjectSpawner).
## Realizuje wzorzec projektowy Template Method (SOLID): centralizuje zarządzanie cyklem życia,
## wyzwalaczami (TriggerMode), warunkami odradzania (RespawnCondition), czasem offline w uśpionych chunkach
## oraz rejestracją w WorldStreamerze. Klasy pochodne odpowiadają wyłącznie za stworzenie konkretnych instancji.
class_name BaseWorldSpawner

# --- STAŁE DOMENOWE I WIZUALNE EDYTORA (Brak magicznych liczb) ---
const DEFAULT_PROXIMITY_RADIUS_PX: float = 500.0
const DEFAULT_SPAWN_CHANCE: float = 1.0
const EDITOR_GIZMO_LINE_WIDTH: float = 2.0
const EDITOR_PROXIMITY_CIRCLE_SEGMENTS: int = 32
const EDITOR_PROXIMITY_LINE_WIDTH: float = 1.0
const EDITOR_PROXIMITY_ALPHA: float = 0.2
## Maksymalny budżet czasu (w ms) na masowe wybudzanie spawnerów w jednej klatce.
const SPAWN_BATCH_FRAME_BUDGET_MSEC: int = 6

static var _last_spawn_batch_frame: int = -1
static var _Batch_frame_start_msec: int = 0

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

## W jakich warunkach spawner ma odrodzić obiekt po pierwszym pojawieniu się?
enum RespawnCondition {
	## Nigdy się nie odradza. Pojawia się raz (lub do limitu max_total_spawns) i koniec.
	NEVER,
	## Klasycznie: Odczekuje czas po śmierci/zebraniu obiektu i odradza go.
	AFTER_DEATH_AND_TIME,
	## Metronom: Spawnuje obiekt co określony czas, ignorując to, czy poprzedni zginął (aż do zapełnienia limitu max_alive_entities).
	TIME_ONLY,
	## Wymaga odświeżenia: Obiekt odrodzi się TYLKO po ponownym załadowaniu chunka (gdy gracz odejdzie daleko i wróci).
	ON_CHUNK_REENTER,
	## Rygorystycznie: Odradza się po powrocie na chunk, ALE musi też minąć określony czas (by nie farmić biegając w przód i w tył).
	ON_CHUNK_REENTER_AND_TIME
}

@export_group("Wyzwalacze i Aktywność")
## Wybierz tryb wyzwalania spawnera.
@export var trigger_mode: TriggerMode = TriggerMode.DIRECTOR_ONLY
## Jeśli fałsz, spawner jest uśpiony i nie zareaguje na żadne bodźce.
@export var is_active: bool = true
## Szansa na to, że ten spawner w ogóle zadziała przy pierwszym uruchomieniu (1.0 = 100%, 0.5 = 50%).
@export_range(0.0, 1.0) var spawn_chance: float = DEFAULT_SPAWN_CHANCE

@export_group("Zarządzanie Cyklem Życia")
## Maksymalna ilość jednocześnie żyjących/istniejących instancji wygenerowanych z tego spawnera.
@export var max_alive_entities: int = 1
## CAŁKOWITY limit użyć tego spawnera w historii gry (0 = nieskończoność). Np. 1 oznacza, że zespawnuje się tylko 1 raz na zawsze.
@export var max_total_spawns: int = 0
## Wybierz zasadę, według której obiekty powracają do gry.
@export var respawn_condition: RespawnCondition = RespawnCondition.NEVER
## Czas (w sekundach) do ponownego spawnu (jeśli zasada z niego korzysta).
@export var respawn_cooldown: float = 0.0

@export_group("Zdarzenia i Zasięgi")
## Używane TYLKO dla trybu 'PROXIMITY_PLAYER'. Określa promień wykrywania gracza w pikselach.
@export var proximity_radius: float = DEFAULT_PROXIMITY_RADIUS_PX:
	set(value):
		proximity_radius = maxf(0.0, value)
		if Engine.is_editor_hint():
			queue_redraw()
## Używane TYLKO dla trybu 'EVENT_BUS_SIGNAL'. Oczekiwane hasło z EventBusa (np. 'boss_fight_started').
@export var expected_event_name: String = ""

# --- WEWNĘTRZNE ŚLEDZENIE STANU ---
var _alive_entities: Array[Node] = []
var _respawn_timer: float = 0.0
var _last_sleep_timestamp: float = 0.0
var _was_on_cooldown_when_sleeping: bool = false
var _total_spawned_count: int = 0

## Flaga zapobiegająca "Fałszywym Startom" przy ładowaniu wielkiej mapy zanim WorldStreamer posegreguje chunki.
var _initial_setup_done: bool = false
## Flaga informująca, że spawner został już po raz pierwszy odbezpieczony swoim głównym wyzwalaczem.
var _is_unlocked: bool = false

## Wywoływane automatycznie, gdy węzeł wchodzi do drzewa sceny (np. przy wybudzeniu chunka przez WorldStreamer).
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	# --- NAPRAWA ZATRZYMANEGO CZASU OFFLINE I OBSŁUGA RE-ENTER ---
	if _was_on_cooldown_when_sleeping:
		var current_time: float = Time.get_unix_time_from_system()
		var time_passed_offline: float = maxf(0.0, current_time - _last_sleep_timestamp)

		if respawn_condition == RespawnCondition.ON_CHUNK_REENTER:
			_respawn_timer = respawn_cooldown
		elif respawn_condition in [
			RespawnCondition.ON_CHUNK_REENTER_AND_TIME,
			RespawnCondition.AFTER_DEATH_AND_TIME,
			RespawnCondition.TIME_ONLY
		]:
			_respawn_timer += time_passed_offline

		_was_on_cooldown_when_sleeping = false

	# --- INTELIGENTNE WZNAWIANIE (Gdy chunk wraca z pamięci RAM) ---
	if _initial_setup_done:
		if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and not _is_unlocked:
			if EventBus.has_method("has_story_event_occurred") and EventBus.has_story_event_occurred(expected_event_name):
				call_deferred("_deferred_budgeted_spawn")
		elif _is_unlocked and (
			trigger_mode == TriggerMode.ON_CHUNK_ACTIVE
			or respawn_condition in [RespawnCondition.ON_CHUNK_REENTER, RespawnCondition.ON_CHUNK_REENTER_AND_TIME]
		):
			call_deferred("_deferred_budgeted_spawn")

## Wywoływane automatycznie, gdy węzeł opuszcza drzewo sceny (np. chunk zostaje uśpiony w RAM-ie).
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_cleanup_invalid_alive_entities()
	if respawn_cooldown > 0.0 and _alive_entities.size() < max_alive_entities:
		_last_sleep_timestamp = Time.get_unix_time_from_system()
		_was_on_cooldown_when_sleeping = true
	elif respawn_condition == RespawnCondition.ON_CHUNK_REENTER and _alive_entities.size() < max_alive_entities:
		_was_on_cooldown_when_sleeping = true

## Wywoływane przy pierwszym zainicjowaniu węzła na scenie.
func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	add_to_group("AdvancedSpawner")

	if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
		if not EventBus.story_event_triggered.is_connected(_on_story_event):
			EventBus.story_event_triggered.connect(_on_story_event)

	await get_tree().process_frame
	_initial_setup_done = true

	if trigger_mode == TriggerMode.ON_CHUNK_ACTIVE:
		_is_unlocked = true
		if is_inside_tree():
			await _deferred_budgeted_spawn()

	if trigger_mode == TriggerMode.EVENT_BUS_SIGNAL and expected_event_name != "":
		if EventBus.has_method("has_story_event_occurred") and EventBus.has_story_event_occurred(expected_event_name):
			if not _is_unlocked and is_inside_tree():
				await _deferred_budgeted_spawn()

## Rozkłada w czasie jednoczesne przebudzenie setek spawnerów na chunku (max 6 ms na klatkę).
func _deferred_budgeted_spawn() -> void:
	while is_inside_tree():
		var current_frame: int = Engine.get_process_frames()
		if current_frame != _last_spawn_batch_frame:
			_last_spawn_batch_frame = current_frame
			_Batch_frame_start_msec = Time.get_ticks_msec()
			break
		if Time.get_ticks_msec() - _Batch_frame_start_msec < SPAWN_BATCH_FRAME_BUDGET_MSEC:
			break
		await get_tree().process_frame
	if is_inside_tree():
		attempt_spawn()

## Główna pętla logiczna spawnera. Odlicza cooldowny i sprawdza dystans do gracza.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active:
		return

	if not _is_unlocked:
		if trigger_mode == TriggerMode.PROXIMITY_PLAYER:
			var player_ref: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
			if is_instance_valid(player_ref):
				var radius_sq: float = proximity_radius * proximity_radius
				if global_position.distance_squared_to(player_ref.global_position) <= radius_sq:
					attempt_spawn()
		return

	if respawn_condition != RespawnCondition.NEVER and respawn_condition != RespawnCondition.ON_CHUNK_REENTER:
		_cleanup_invalid_alive_entities()
		var should_count: bool = _alive_entities.size() < max_alive_entities

		if should_count and respawn_cooldown > 0.0:
			_respawn_timer += delta
			if _respawn_timer >= respawn_cooldown and respawn_condition != RespawnCondition.ON_CHUNK_REENTER_AND_TIME:
				attempt_spawn()

## Główna metoda szablonowa (Template Method) tworząca byt.
func attempt_spawn() -> void:
	if not is_active or not _has_valid_spawn_configuration():
		return

	_is_unlocked = true

	if _total_spawned_count == 0 and randf() > spawn_chance:
		is_active = false
		return

	if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
		return

	if respawn_condition == RespawnCondition.NEVER and _total_spawned_count >= max_alive_entities:
		return

	if respawn_condition == RespawnCondition.ON_CHUNK_REENTER_AND_TIME and _respawn_timer < respawn_cooldown:
		if _total_spawned_count > 0:
			return

	_cleanup_invalid_alive_entities()
	if _alive_entities.size() >= max_alive_entities:
		return

	var spawned_nodes: Array[Node] = _create_spawn_nodes()
	if not spawned_nodes.is_empty():
		for node in spawned_nodes:
			if node is Node2D:
				_finalize_spawn(node as Node2D)
		_respawn_timer = 0.0
		_total_spawned_count += 1

		if max_total_spawns > 0 and _total_spawned_count >= max_total_spawns:
			is_active = false

## Nadaje obiektowi pozycję, przypina go do odpowiedniego miejsca na mapie i rejestruje w WorldStreamerze.
func _finalize_spawn(entity: Node2D) -> void:
	var spawn_pos: Vector2 = _calculate_entity_spawn_position(entity)
	entity.global_position = spawn_pos

	var parent_target: Node = get_parent()
	var map_region: MapRegion = _get_map_region()

	if map_region != null:
		var entities_node: Node = map_region.find_child("Entities", false, false)
		if entities_node != null:
			parent_target = entities_node

	if parent_target != null:
		parent_target.call_deferred("add_child", entity)
		entity.set_deferred("global_position", spawn_pos)

	_alive_entities.append(entity)

	var streamer: Node = _find_world_streamer(map_region)
	if streamer != null and streamer.has_method("register_entity"):
		streamer.call_deferred("register_entity", entity)

## Usuwa z listy żywych obiektów te, które zostały już zniszczone lub zebrane przez gracza.
func _cleanup_invalid_alive_entities() -> void:
	for i in range(_alive_entities.size() - 1, -1, -1):
		var entity: Node = _alive_entities[i]
		if not is_instance_valid(entity) or entity.is_queued_for_deletion():
			_alive_entities.remove_at(i)

## Szybkie wyszukiwanie WorldStreamera bez kosztownego przeszukiwania całego drzewa sceny (O(1)).
func _find_world_streamer(map_region: MapRegion) -> Node:
	if map_region != null:
		var regional_streamer: Node = map_region.get_node_or_null("WorldStreamer")
		if regional_streamer != null:
			return regional_streamer
	if is_inside_tree():
		return get_tree().get_first_node_in_group("WorldStreamer")
	return null

func _on_story_event(event_name: String) -> void:
	if event_name == expected_event_name:
		attempt_spawn()

func _get_map_region() -> MapRegion:
	var curr: Node = get_parent()
	while curr != null:
		if curr is MapRegion:
			return curr as MapRegion
		curr = curr.get_parent()
	return null

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_spawner_icon()
	if trigger_mode == TriggerMode.PROXIMITY_PLAYER:
		var gizmo_col: Color = _get_gizmo_color()
		var prox_col: Color = Color(gizmo_col.r, gizmo_col.g, gizmo_col.b, EDITOR_PROXIMITY_ALPHA)
		draw_arc(
			Vector2.ZERO,
			proximity_radius,
			0.0,
			TAU,
			EDITOR_PROXIMITY_CIRCLE_SEGMENTS,
			prox_col,
			EDITOR_PROXIMITY_LINE_WIDTH
		)

# =========================================================================
# METODY WIRTUALNE DO NADPISANIA W KLASACH POCHODNYCH (SOLID - OCP / LSP)
# =========================================================================

func _has_valid_spawn_configuration() -> bool:
	return false

func _create_spawn_nodes() -> Array[Node]:
	return []

func _calculate_entity_spawn_position(_entity: Node2D) -> Vector2:
	return global_position

func _draw_spawner_icon() -> void:
	pass

func _get_gizmo_color() -> Color:
	return Color.WHITE
