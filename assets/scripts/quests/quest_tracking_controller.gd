class_name QuestTrackingController
extends RefCounted

## Powiadamia interfejs o zmianie śledzonego zadania.
signal tracked_quest_changed(quest_id: StringName)

## Zadanie aktualnie przypięte do interfejsu gracza.
var tracked_quest_id: StringName = &""

## Kolejka aktywnych zadań oczekujących na automatyczne śledzenie.
var _tracking_queue: Array[StringName] = []

## Dodaje zadanie do kolejki śledzenia, zachowując FIFO aktywnych zadań.
func queue_quest(quest_id: StringName, active_quests: Dictionary, quest_db: Dictionary) -> void:
	if tracked_quest_id == quest_id or _tracking_queue.has(quest_id):
		return

	_tracking_queue.append(quest_id)
	if tracked_quest_id == &"":
		_promote_next_queued_quest(active_quests, quest_db)

## Usuwa zadanie z kolejki, np. po jego ukończeniu albo porażce.
func remove_quest(quest_id: StringName) -> void:
	_tracking_queue.erase(quest_id)

## Przypina najstarsze nadal aktywne zadanie oczekujące w kolejce.
func promote_next_queued_quest(active_quests: Dictionary, quest_db: Dictionary) -> void:
	_promote_next_queued_quest(active_quests, quest_db)

## Ręcznie przypina aktywne zadanie i zachowuje poprzednie na początku kolejki.
func track_quest(quest_id: StringName, active_quests: Dictionary, quest_db: Dictionary) -> void:
	if not active_quests.has(quest_id) or tracked_quest_id == quest_id:
		return

	if tracked_quest_id != &"" and active_quests.has(tracked_quest_id):
		_tracking_queue.erase(tracked_quest_id)
		_tracking_queue.push_front(tracked_quest_id)

	_tracking_queue.erase(quest_id)
	tracked_quest_id = quest_id
	tracked_quest_changed.emit(quest_id)
	print("QuestManager: Śledzę zadanie [", quest_db[quest_id].title, "]")

## Zdejmuje obecne zadanie ze śledzenia i promuje następne aktywne zadanie z kolejki.
func untrack_quest(active_quests: Dictionary, quest_db: Dictionary) -> void:
	if tracked_quest_id != &"":
		_tracking_queue.erase(tracked_quest_id)
	_promote_next_queued_quest(active_quests, quest_db)

## Czyści kolejkę śledzenia i odświeża interfejs tylko wtedy, gdy śledzenie było aktywne.
func reset() -> void:
	var was_tracking_quest := tracked_quest_id != &""
	_tracking_queue.clear()
	tracked_quest_id = &""

	if was_tracking_quest:
		tracked_quest_changed.emit(&"")

func _promote_next_queued_quest(active_quests: Dictionary, quest_db: Dictionary) -> void:
	while not _tracking_queue.is_empty():
		var next_quest_id: StringName = _tracking_queue.pop_front()
		if active_quests.has(next_quest_id):
			tracked_quest_id = next_quest_id
			tracked_quest_changed.emit(tracked_quest_id)
			if quest_db.has(next_quest_id):
				print("QuestManager: Automatycznie śledzę zadanie [", quest_db[next_quest_id].title, "]")
			return

	tracked_quest_id = &""
	tracked_quest_changed.emit(&"")
