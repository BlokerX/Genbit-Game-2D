extends Resource
class_name DialogueLine

@export var speaker: SpeakerData
## Czas (w sekundach), przez który gracz nie może pominąć tekstu ani kliknąć odpowiedzi
@export var min_skip_time: float = 0.5
@export_multiline var dialogue_text: String = "Dialogue text..."
## Lista możliwych odpowiedzi gracza
@export var choices: Array[DialogueChoice] = []
