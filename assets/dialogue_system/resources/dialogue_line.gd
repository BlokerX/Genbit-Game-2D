extends Resource
class_name DialogueLine

@export var speaker_name: String = "Stranger"
@export var speaker_portrait: Texture2D
@export_multiline var dialogue_text: String = "Dialogue text..."
## Lista możliwych odpowiedzi gracza
@export var choices: Array[DialogueChoice] = []
