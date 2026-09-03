extends Resource
class_name DialogueNode

@export var id: StringName = &""
@export var speaker: SpeakerData
@export var min_skip_time: float = 0.5
@export_multiline var dialogue_text: String = ""

# Zamiast osobnego 'choices' i 'next_line' mamy jedno pojęcie: wyjścia (krawędzie)
@export var outputs: Array[DialogueConnection] = []
@export var allow_cancel: bool = false
