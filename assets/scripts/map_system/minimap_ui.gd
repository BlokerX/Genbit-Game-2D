extends Control

@export var room_map: RoomMap
@export var cell_size: Vector2 = Vector2(20, 20)
@export var spacing: int = 4

func _draw() -> void:
	var matrix = room_map.get_minimap_matrix()
	if matrix.is_empty(): return

	for y in range(matrix.size()):
		for x in range(matrix[y].size()):
			var room_info = matrix[y][x]
			
			# Pozycja rysowania na ekranie
			var draw_pos = Vector2(x * (cell_size.x + spacing), y * (cell_size.y + spacing))
			
			if room_info != null:
				# Rysowanie prostokąta pokoju
				var rect = Rect2(draw_pos, cell_size)
				var color = Color.WHITE
				
				# Możesz zmienić kolor, jeśli to aktualny pokój
				# if room_info.id == current_room_id: color = Color.GREEN
				
				draw_rect(rect, color)
				
				# Opcjonalnie: Rysowanie połączeń (drzwi)
				_draw_connections(room_info, draw_pos, matrix)
			else:
				# Puste miejsce (opcjonalnie kropka lub nic)
				pass

func _draw_connections(room_info, pos, matrix):
	# Tutaj można dodać linię łączącą kwadraciki na podstawie room_info.connections
	pass
