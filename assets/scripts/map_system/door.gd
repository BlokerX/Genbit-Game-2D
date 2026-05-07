extends Area2D
class_name Door

## Własny sygnał, który wyślemy, gdy gracz dotknie drzwi.
## Będziemy mogli go później odebrać w głównym skrypcie zarządzającym poziomami.
signal player_entered_door(door_node)

@export_group("Konfiguracja Drzwi")
## Możesz w przyszłości wpisywać tu np. nazwę pokoju, do którego prowadzą drzwi.
@export var destination_room : String = ""

func _ready() -> void:
	# Automatycznie podłączamy sygnał z Area2D, gdy coś w nią wejdzie
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Sprawdzamy, czy obiekt, który wszedł w drzwi, to gracz.
	# Najprościej to zrobić, sprawdzając grupę.
	if body.is_in_group("Player"):
		print("Gracz wszedł w drzwi!")
		
		# Wysyłamy nasz sygnał, przekazując same drzwi (self), 
		# żeby główny menedżer gry wiedział, które drzwi zostały aktywowane.
		player_entered_door.emit(self)
