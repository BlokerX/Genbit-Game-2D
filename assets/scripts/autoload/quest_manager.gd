extends Node

## Autoload / Menedżer Zadań (QuestManager).
## Główny, zoptymalizowany pod kątem wydajności (O(1)) i niezależny system 
## zarządzający pełnym cyklem życia zadań fabularnych. Nasłuchuje globalnych zdarzeń
## poprzez EventBus i weryfikuje cele w tle.

const QuestObjectiveProgressControllerType = preload(
	"res://assets/scripts/quests/quest_objective_progress_controller.gd"
)
const QuestTrackingControllerType = preload(
	"res://assets/scripts/quests/quest_tracking_controller.gd"
)
const QuestTimerControllerType = preload(
	"res://assets/scripts/quests/quest_timer_controller.gd"
)

# ==========================================
# SYGNAŁY (Emitowane do UI Dziennika Zadań)
# ==========================================

## Emitowany, gdy gracz po raz pierwszy otrzymuje nowe zadanie.
signal quest_started(quest: QuestData)

## Emitowany, gdy zadanie przeskakuje na kolejny, nowy etap (Stage).
signal quest_updated(quest: QuestData, current_stage: int)

## Emitowany, gdy postęp wewnątrz konkretnego celu etapu (Objective) ulega zmianie.
signal quest_objective_progressed(quest: QuestData, objective_index: int, current_count: int)

## Emitowany, gdy zadanie zostaje w pełni ukończone sukcesem.
signal quest_completed(quest: QuestData)

## Emitowany, gdy zadanie zostaje zakończone porażką (lub porzucone).
signal quest_failed(quest: QuestData)

signal quest_tracked_changed(quest_id: StringName)

# ==========================================
# PAMIĘĆ / BAZA DANYCH
# ==========================================

## Główna baza wszystkich wczytanych zadań z plików .tres. Klucz to 'id' (StringName).
var quest_db: Dictionary = {}

# active_quests teraz przechowuje słownik z etapem i postępem celów:
# { quest_id: { "stage": int, "progress": Dictionary, "timer": float } }
## Słownik przechowujący stan aktualnie wykonywanych zadań przez gracza.
var active_quests: Dictionary = {} 

## Lista identyfikatorów zadań zakończonych sukcesem.
var completed_quests: Array[StringName] = []

## Lista identyfikatorów zadań zakończonych porażką lub porzuconych.
var failed_quests: Array[StringName] = []

## Słownik śledzący odnawianie się zadań powtarzalnych (Daily Quests). Format: { quest_id: time_left }
var cooldown_quests: Dictionary = {} 

## Obecnie śledzone zadanie (przypięte do ekranu)
var tracked_quest_id: StringName:
	get:
		return _tracking_controller.tracked_quest_id
	set(value):
		_tracking_controller.tracked_quest_id = value
## Unieważnia opóźnione akcje zadań, gdy kończy się sesja.
var _session_generation: int = 0
var _tracking_controller: QuestTrackingControllerType = QuestTrackingControllerType.new()
var _timer_controller: QuestTimerControllerType = QuestTimerControllerType.new()
var _objective_progress_controller: QuestObjectiveProgressControllerType = (
	QuestObjectiveProgressControllerType.new()
)

# ==========================================
# GŁÓWNA LOGIKA
# ==========================================

## Inicjalizacja przy starcie gry.
func _ready() -> void:
	_load_all_quests("res://assets/data/quests/")
	if not _tracking_controller.tracked_quest_changed.is_connected(_on_tracked_quest_changed):
		_tracking_controller.tracked_quest_changed.connect(_on_tracked_quest_changed)
	
	# Nasłuchujemy całego świata! (Upewnij się, że masz ten sygnał w event_bus.gd)
	if EventBus.has_signal("game_event_occurred") and not EventBus.game_event_occurred.is_connected(_on_game_event):
		EventBus.game_event_occurred.connect(_on_game_event)

func _on_tracked_quest_changed(quest_id: StringName) -> void:
	quest_tracked_changed.emit(quest_id)


## Pętla gry, obsługująca upływ czasu (Timery limitowe w questach i ich Cooldowny po zakończeniu).
func _process(delta: float) -> void:
	_timer_controller.process_timers(
		delta,
		active_quests,
		quest_db,
		cooldown_quests,
		completed_quests,
		failed_quests,
		Callable(self, "fail_quest")
	)


# --- SYSTEM CZUJNIKÓW I CELÓW ---
## Metoda wywoływana za każdym razem, gdy gra zgłasza dowolne wydarzenie fabularne/mechaniczne (EventBus).
func _on_game_event(event_type: String, event_data: Dictionary) -> void:
	_objective_progress_controller.process_game_event(
		event_type,
		event_data,
		active_quests,
		quest_db,
		Callable(self, "_emit_objective_progressed"),
		Callable(self, "advance_to_next_stage")
	)

func _emit_objective_progressed(
	quest: QuestData,
	objective_index: int,
	current_count: int
) -> void:
	quest_objective_progressed.emit(quest, objective_index, current_count)


# --- ZARZĄDZANIE ETAPAMI ---

## Pcha questa bezpiecznie o 1 etap do przodu, weryfikując jego stan.
func advance_to_next_stage(quest_id: StringName) -> void:
	if completed_quests.has(quest_id) or failed_quests.has(quest_id): 
		print("QuestManager: Odmowa awansu. Zadanie [", quest_id, "] zostało już wcześniej ukończone lub oblało.")
		return
		
	var current_stage = -1
	if active_quests.has(quest_id):
		current_stage = active_quests[quest_id]["stage"]
		
	update_quest(quest_id, current_stage + 1)


## Rozpoczyna nowe zadanie z inicjatywy gracza i nadaje mu priorytet śledzenia.
func start_quest(quest_id: StringName, initial_stage: int = 0) -> void:
	if active_quests.has(quest_id):
		return

	_update_quest(quest_id, initial_stage, true)

## Bezpośrednio aktualizuje zadanie do wskazanego etapu (lub rozpoczyna je, jeśli to etap 0).
func update_quest(quest_id: StringName, stage_index: int) -> void:
	_update_quest(quest_id, stage_index, false)

## Wspólna implementacja aktualizacji etapu, z opcjonalnym priorytetem dla ręcznego startu.
func _update_quest(quest_id: StringName, stage_index: int, prioritize_tracking: bool) -> void:
	if completed_quests.has(quest_id) or failed_quests.has(quest_id):
		print("QuestManager: Odmowa aktualizacji. Zadanie [", quest_id, "] jest już w archiwum (sukces/porażka).")
		return
		
	if not quest_db.has(quest_id):
		push_error("BŁĄD KRYTYCZNY QuestManager: Nie znaleziono zadania w bazie! Szukane ID: '", quest_id, "'.")
		return
		
	var quest: QuestData = quest_db[quest_id]
	if stage_index >= quest.stages.size():
		print("QuestManager: Osiągnięto koniec etapów dla [", quest.title, "]. Zamykam zadanie.")
		complete_quest(quest_id)
		return
		
	var current_stage = -1
	if active_quests.has(quest_id):
		current_stage = active_quests[quest_id]["stage"]
		
	if stage_index <= current_stage: 
		print("QuestManager: Odrzucono próbę cofnięcia/zapętlenia etapu. Etap ", stage_index, " jest już aktywny lub minął.")
		return
		
	var stage_data: QuestStage = quest.stages[stage_index]
	var is_new_quest = not active_quests.has(quest_id)
	
	active_quests[quest_id] = {
		"stage": stage_index,
		"progress": {},
		"timer": quest.time_limit_seconds if is_new_quest else active_quests[quest_id].get("timer", 0.0)
	}
	
	if is_new_quest:
		quest_started.emit(quest)
		print("Quest: Rozpoczęto zadanie [", quest.title, "]")
		_queue_quest_for_tracking(quest_id)
		if prioritize_tracking:
			track_quest(quest_id)
	else:
		quest_updated.emit(quest, stage_index)
		print("Quest: Zaktualizowano zadanie [", quest.title, "]")
	
	if stage_data.trigger_event_on_start != "":
		EventBus.story_event_triggered.emit(stage_data.trigger_event_on_start)
		
	_grant_rewards(stage_data.start_rewards)
	
	# --- MAGIA: Jeśli dopiero co otrzymaliśmy zadanie, natychmiast odpytujemy ekwipunek Gracza! ---
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_inventory"):
		_on_game_event("inventory_changed", {"inventory": player.get_inventory()})
	else:
		print("QuestManager: Ostrzeżenie - nie znaleziono ekwipunku gracza do automatycznej weryfikacji.")
	
	# --- NOWOŚĆ: AUTO ZALICZANIE ETAPU ZEROWEGO ---
	if is_new_quest and quest.get("auto_complete_first_stage") == true:
		var delay = quest.get("auto_complete_delay")
		var scheduled_generation := _session_generation
		if delay > 0.0:
			# Używamy timera, ale dla bezpieczeństwa w locie weryfikujemy stan questa
			get_tree().create_timer(delay).timeout.connect(func():
				if (
					scheduled_generation == _session_generation
					and active_quests.has(quest_id)
					and active_quests[quest_id]["stage"] == 0
				):
					advance_to_next_stage(quest_id)
			)
		else:
			# Odroczenie na koniec klatki (call_deferred) chroni przed ucięciem innych sygnałów startowych
			call_deferred("advance_to_next_stage", quest_id)


## Kończy zadanie sukcesem, przyznaje nagrody i uruchamia łańcuchy (jeśli istnieją).
func complete_quest(quest_id: StringName) -> void:
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)
		_remove_quest_from_tracking_queue(quest_id)
		completed_quests.append(quest_id)
		
		var quest: QuestData = quest_db[quest_id]
		
		# POPRAWKA 2: Obsługa 0.0 Cooldownu (natychmiastowe odnowienie)
		if quest.is_repeatable:
			if quest.cooldown_seconds > 0.0:
				cooldown_quests[quest_id] = quest.cooldown_seconds
			else:
				completed_quests.erase(quest_id)
				print("QuestManager: Zadanie odnawialne [", quest.title, "] zostało natychmiastowo zresetowane (0s cooldown).")
			
		quest_completed.emit(quest)
		print("Quest: Zakończono sukcesem zadanie [", quest.title, "]")
		
		if quest.completion_event != "":
			EventBus.story_event_triggered.emit(quest.completion_event)
			
		_grant_rewards(quest.completion_rewards)
		
		# Jeśli śledziliśmy to zadanie, automatycznie wybieramy następne z kolejki.
		if tracked_quest_id == quest_id:
			_promote_next_queued_quest()
		
		if quest.next_quest_in_chain != null:
			print("Quest: Automatyczne rozpoczęcie kolejnego ogniwa z łańcucha dla: ", quest.next_quest_in_chain.id)
			update_quest(quest.next_quest_in_chain.id, 0)
	else:
		print("QuestManager: Zignorowano próbę zakończenia [", quest_id, "], ponieważ nie figuruje w aktywnych zadaniach.")


## Kończy zadanie porażką (np. śmierć eskortowanego NPC lub upływ czasu).
func fail_quest(quest_id: StringName) -> void:
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)
		_remove_quest_from_tracking_queue(quest_id)
		failed_quests.append(quest_id)
		
		if tracked_quest_id == quest_id:
			_promote_next_queued_quest()
		
		var quest: QuestData = quest_db[quest_id]
		
		# POPRAWKA 2: Obsługa 0.0 Cooldownu po porażce
		if quest.is_repeatable:
			if quest.cooldown_seconds > 0.0:
				cooldown_quests[quest_id] = quest.cooldown_seconds
			else:
				failed_quests.erase(quest_id)
				print("QuestManager: Oblane zadanie [", quest.title, "] jest ponownie dostępne do wzięcia (0s cooldown).")
			
		quest_failed.emit(quest)
		print("Quest: ZADANIE ZAKOŃCZONE PORAŻKĄ [", quest.title, "]")
		
		if quest.failure_event != "":
			EventBus.story_event_triggered.emit(quest.failure_event)
	else:
		print("QuestManager: Zignorowano próbę oblania [", quest_id, "], ponieważ nie figuruje w aktywnych zadaniach.")


## Ręczne porzucenie zadania przez gracza (dostępne tylko dla zadań z flagą is_skippable).
func abandon_quest(quest_id: StringName) -> void:
	var quest: QuestData = quest_db.get(quest_id)
	if quest:
		if quest.is_skippable:
			print("Quest: Gracz ręcznie porzucił zadanie [", quest.title, "]")
			fail_quest(quest_id)
		else:
			print("QuestManager: Odmowa. Zadanie [", quest.title, "] jest oznaczone jako niepomijalne (is_skippable = false).")
	else:
		print("QuestManager: Błąd porzucenia. Nie odnaleziono zadania w bazie danych: ", quest_id)


## Funkcja wewnętrzna nakładająca fizyczne nagrody (Efekty) na postać Gracza.
func _grant_rewards(rewards: Array[Effect]) -> void:
	if rewards.is_empty(): return
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("receive_effect"):
		for effect in rewards:
			if effect != null:
				player.receive_effect(effect.duplicate(true))
	else:
		print("QuestManager: Błąd! Nie udało się nałożyć nagród - gracz nie istnieje lub brakuje mu funkcji receive_effect.")


## Procedura inicjalizacyjna - skanuje folder i mapuje zasoby QuestData.
func _load_all_quests(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("QuestManager: OSTRZEŻENIE! Brak folderu z questami pod ścieżką: " + path)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.replace(".remap", "").ends_with(".tres"):
			var res = load(path.path_join(file_name.replace(".remap", "")))
			if res is QuestData:
				quest_db[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	print("QuestManager: Gotowość systemu. Załadowano ", quest_db.size(), " zadań fabularnych do bazy.")


## Dodaje nowe aktywne zadanie do kolejki automatycznego śledzenia.
func _queue_quest_for_tracking(quest_id: StringName) -> void:
	_tracking_controller.queue_quest(quest_id, active_quests, quest_db)

## Usuwa zadanie z kolejki, np. po jego ukończeniu albo porażce.
func _remove_quest_from_tracking_queue(quest_id: StringName) -> void:
	_tracking_controller.remove_quest(quest_id)

## Przypina najstarsze nadal aktywne zadanie oczekujące w kolejce.
func _promote_next_queued_quest() -> void:
	_tracking_controller.promote_next_queued_quest(active_quests, quest_db)

# --- NOWOŚĆ: FUNKCJE ŚLEDZENIA ZADAŃ ---
## Ręcznie przypina aktywne zadanie i zachowuje poprzednie na początku kolejki.
func track_quest(quest_id: StringName) -> void:
	_tracking_controller.track_quest(quest_id, active_quests, quest_db)

## Zdejmuje obecne zadanie ze śledzenia i promuje następne aktywne zadanie z kolejki.
func untrack_quest() -> void:
	_tracking_controller.untrack_quest(active_quests, quest_db)

## Czyści postęp i śledzenie zadań bez zwalniania załadowanej bazy danych.
func reset_game_session() -> void:
	_session_generation += 1
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	cooldown_quests.clear()
	_tracking_controller.reset()
