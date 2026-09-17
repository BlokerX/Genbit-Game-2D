extends Resource
class_name QuestData

enum QuestCategory { MAIN_STORY, SIDE_QUEST, CONTRACT, HIDDEN }

@export_group("Główne Informacje")
@export var id: StringName = &"quest_id"
@export var title: String = "Tytuł Zadania"
@export_multiline var description: String = "Opis fabularny zadania."
@export var category: QuestCategory = QuestCategory.MAIN_STORY

@export_group("Opcje Zaawansowane (Czas i Porażka)")
## Czy gracz może ręcznie porzucić to zadanie w dzienniku?
@export var is_skippable: bool = false
## Czas w sekundach na ukończenie zadania (0 = brak limitu czasu).
@export var time_limit_seconds: float = 0.0

@export_group("Odnawialność (Repeatable)")
## Czy zadanie można wykonać ponownie po jego zakończeniu?
@export var is_repeatable: bool = false
## Czas (w sekundach), po którym zadanie znika z listy "Ukończonych" i może być wzięte ponownie. (system typu daily quests)
@export var cooldown_seconds: float = 0.0

@export_group("Struktura")
## Poszczególne etapy questa jako potężne bloki danych.
@export var stages: Array[QuestStage] = []

@export_group("Finał Zadania (Sukces)")
@export_multiline var completed_summary: String = "Udało mi się zakończyć to zadanie z sukcesem."
## Hasło wysyłane w świat po całkowitym ukończeniu zadania.
@export var completion_event: String = ""
## Nagrody końcowe za questa (XP, złoto, unikalne itemy).
@export var completion_rewards: Array[Effect] = []
## Jeśli wrzucisz tu inny QuestData, wystartuje on automatycznie po sukcesie tego.
@export var next_quest_in_chain: QuestData = null

@export_group("Finał Zadania (Porażka)")
@export_multiline var failed_summary: String = "Niestety, zawiodłem."
## Hasło rzucane w świat gry, gdy zadanie zostanie oblane (lub minie czas).
@export var failure_event: String = ""
