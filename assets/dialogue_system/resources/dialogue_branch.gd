extends Resource
class_name DialogueBranch

## Linia, która zostanie załadowana, jeśli warunki poniżej są spełnione
@export var start_line: DialogueLine
## Warunki aktywacji tego powitania (np. flaga "zabilem_smoka")
@export var conditions: Array[ItemCondition] = []
