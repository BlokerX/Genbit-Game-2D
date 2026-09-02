extends Resource
class_name DialogueChoice

@export var choice_text: String = "Response..."
## Opcjonalna ikona
@export var choice_icon: Texture2D
@export var next_line: DialogueLine

@export_group("Wymagania i Konsekwencje (Zaawansowane)")
## Warunki, które gracz musi spełnić, aby ta opcja była WIDOCZNA
@export var conditions: Array[ItemCondition] = []
## Efekty, które zostaną nałożone na gracza po wybraniu tej opcji (np. obrażenia, loot)
@export var consequences: Array[Effect] = []
