extends Resource
class_name QuestData

@export_group("Główne Informacje")
@export var id: StringName = &"quest_id"
@export var title: String = "Tytuł Zadania"
@export_multiline var description: String = "Opis fabularny zadania."

@export_group("Struktura")
## Poszczególne etapy questa jako potężne bloki danych.
@export var stages: Array[QuestStage] = []

@export_group("Finał Zadania")
## Hasło wysyłane w świat po całkowitym ukończeniu zadania.
@export var completion_event: String = ""

## Nagrody końcowe za questa (XP, złoto, unikalne itemy).
@export var completion_rewards: Array[Effect] = []
