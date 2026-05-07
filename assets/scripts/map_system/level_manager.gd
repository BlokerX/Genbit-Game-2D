extends Node
class_name LevelManager

@export_group("Główne Obiekty")
@export var player: CharacterBody2D
@export var starting_room: Room

var current_room: Room
var all_rooms: Array[Room] = []

func _ready() -> void:
	# 1. Zbieramy wszystkie pokoje, zapisujemy do tablicy i wyrzucamy z drzewa sceny
	for child in get_children():
		if child is Room:
			all_rooms.append(child)
			remove_child(child) # To usuwa pokój z fizyki i widoku, ale zostaje w pamięci!
	
	# 2. Aktywujemy tylko pokój startowy
	if starting_room:
		change_room(starting_room)
	else:
		push_warning("LevelManager: Nie przypisano starting_room!")

func change_room(new_room: Room) -> void:
	# 1. Deaktywacja obecnego pokoju
	if current_room:
		_disconnect_door_signals(current_room)
		# Całkowicie usuwamy stary pokój z drzewa sceny (kolizje znikają)
		if current_room.is_inside_tree():
			remove_child(current_room) 
		
	# 2. Aktywacja nowego pokoju
	current_room = new_room
	
	# Dodajemy nowy pokój z powrotem do drzewa (pojawia się grafika i kolizje)
	if not current_room.is_inside_tree():
		add_child(current_room)
		
	_connect_door_signals(current_room)
	
	# 3. Opcjonalnie: Przeniesienie gracza (jeśli używasz spawn pointów)
	if current_room.spawn_points.size() > 0 and player:
		player.global_position = current_room.spawn_points[0].global_position

func _connect_door_signals(room: Room) -> void:
	for node in room.doors:
		var door = node as Door
		if door and not door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.connect(_on_door_entered)

func _disconnect_door_signals(room: Room) -> void:
	for node in room.doors:
		var door = node as Door
		if door and door.player_entered_door.is_connected(_on_door_entered):
			door.player_entered_door.disconnect(_on_door_entered)

func _on_door_entered(door: Door) -> void:
	var next_room = door.destination_room
	if next_room:
		# call_deferred upewnia się, że usunięcie pokoju z drzewa 
		# nie nastąpi w samym środku obliczania kolizji przez silnik
		call_deferred("change_room", next_room)
	else:
		print("Te drzwi nie mają przypisanego destination_room!")
