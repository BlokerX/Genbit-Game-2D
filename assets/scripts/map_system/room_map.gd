extends Node
class_name RoomMap

@export_group("Konfiguracja Mapy")
## Dodaliśmy "grid_pos", aby określić ułożenie pokoju na minimapie
@export var map_data: Array[Dictionary] = [
	{
		"room_scene": null,             # (PackedScene) Scena pokoju
		"door_ids": [],                 # (Array[int]) Lista ID drzwi w pokoju
		"teleports": [],                # (Array[int]) Połączenia do innych pokojów
		"grid_pos": Vector2i(0, 0),     # (Vector2i) Pozycja pokoju na minimapie (X, Y)
		"room_name": "Start"            # (String) Opcjonalnie: nazwa pokoju do minimapy
	}
]

var current_room: Room

# ... (Tutaj funkcje _ready, _connect_doors, _on_door_entered z poprzedniego kodu) ...

## Generuje i zwraca macierz (tablicę dwuwymiarową) układu pokojów.
## Puste pola to `null`, a zajęte to referencja do słownika pokoju.
func get_minimap_matrix() -> Array:
	if map_data.is_empty():
		return []

	# 1. Szukamy skrajnych punktów mapy (minimum i maksimum dla X i Y)
	# Pozwala to rysować mapę nawet, jeśli używasz ujemnych współrzędnych (np. pokój w -2, -1)
	var min_x = map_data[0].get("grid_pos", Vector2i.ZERO).x
	var max_x = min_x
	var min_y = map_data[0].get("grid_pos", Vector2i.ZERO).y
	var max_y = min_y

	for room_info in map_data:
		var pos: Vector2i = room_info.get("grid_pos", Vector2i.ZERO)
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y

	# 2. Obliczamy wymiary macierzy
	var width = (max_x - min_x) + 1
	var height = (max_y - min_y) + 1

	# 3. Tworzymy pustą macierz wypełnioną wartościami `null`
	var matrix = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(null)
		matrix.append(row)

	# 4. Wypełniamy macierz danymi z naszych pokojów
	for room_info in map_data:
		var pos: Vector2i = room_info.get("grid_pos", Vector2i.ZERO)
		
		# Normalizujemy pozycję (przesuwamy tak, aby najmniejszy X i Y był zawsze równy 0)
		var grid_x = pos.x - min_x
		var grid_y = pos.y - min_y
		
		# Wstawiamy cały słownik z danymi pokoju (dzięki temu z minimapy odczytasz np. nazwę pokoju)
		matrix[grid_y][grid_x] = room_info 

	return matrix


## Pomocnicza funkcja do testowania, wyświetla minimapę w konsoli
func debug_print_minimap() -> void:
	var matrix = get_minimap_matrix()
	print("--- MINIMAPA ---")
	for row in matrix:
		var row_string = ""
		for cell in row:
			if cell == null:
				row_string += "[   ] " # Puste miejsce
			else:
				# Jeśli jest pokój, wyświetl pierwszą literę jego nazwy (lub X)
				var symbol = cell.get("room_name", "X").substr(0, 1)
				row_string += "[" + symbol + " ] " 
		print(row_string)
	print("----------------")
