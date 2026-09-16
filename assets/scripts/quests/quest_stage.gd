extends Resource
class_name QuestStage

@export_multiline var objective_text: String = "Opis celu dla gracza"

@export_group("Zdarzenia w Świecie")
## Jeśli wpiszesz tu np. "spawn_boss", po wejściu w ten etap QuestManager sam wyśle ten sygnał w świat.
@export var trigger_event_on_start: String = ""

@export_group("Nagrody za wejście w etap")
## Przedmioty/Efekty, które gracz dostaje przy rozpoczęciu tego etapu (np. Klucz do lochu)
@export var start_rewards: Array[Effect] = []
