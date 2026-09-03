extends Resource
class_name DialogueConnection

@export var text: String = ""
# Zamiast bezpośredniego wskaźnika do zasobu, używamy ID węzła docelowego
@export var target_id: StringName = &"" 

@export_group("Opcje Systemowe")
@export var choice_icon: Texture2D
@export var log_choice: bool = true
@export var custom_speaker: SpeakerData

@export_group("Warunki i Konsekwencje")
@export var conditions: Array[ItemCondition] = []
@export var consequences: Array[Effect] = []
