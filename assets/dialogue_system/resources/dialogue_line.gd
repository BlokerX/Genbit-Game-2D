extends Resource
class_name DialogueLine

@export var speaker: SpeakerData
## Czas (w sekundach), przez który gracz nie może pominąć tekstu ani kliknąć odpowiedzi
@export var min_skip_time: float = 0.5
@export_multiline var dialogue_text: String = "Dialogue text..."
## Lista możliwych odpowiedzi gracza
@export var choices: Array[DialogueChoice] = []

@export_group("Opcje Systemowe")
## Jeśli włączone, na końcu listy wyborów (lub w trakcie przejścia) pojawi się opcja "Odejdź", która od razu zamknie okno.
@export var allow_cancel: bool = false

@export_group("Płynne Przejścia (Brak Wyborów)")
## Ładuje kolejną linię, omijając wybory (NPC mówi dalej sam).
@export var next_line: DialogueLine
