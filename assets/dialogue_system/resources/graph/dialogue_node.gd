extends Resource
class_name DialogueNode

@export var id: StringName = &""
@export var speaker: SpeakerData
@export var min_skip_time: float = 0.5
@export_multiline var dialogue_text: String = ""

# Zamiast osobnego 'choices' i 'next_line' mamy jedno pojęcie: wyjścia (krawędzie)
@export var outputs: Array[DialogueConnection] = []
@export var allow_cancel: bool = false

# Domyślnie zwykły węzeł dialogowy nie jest automatyczny
func is_auto_advance() -> bool:
	return false

# Jeśli węzeł jest automatyczny, ta funkcja wykonuje jego logikę
# i zwraca ID węzła, do którego Runner ma natychmiast przeskoczyć.
func process_auto_logic(interactor: Node) -> StringName:
	return &""
