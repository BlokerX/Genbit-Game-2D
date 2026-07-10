extends Node
class_name BuilderComponent

@export var player_inventory: Inventory # Podepnij węzeł Inventory gracza w Inspektorze!

var current_build_scene: PackedScene = null
var refund_item: ItemData = null
var ghost_instance: Node2D = null
var is_building: bool = false

func _process(_delta: float) -> void:
	if not is_building or not is_instance_valid(ghost_instance):
		return
		
	# Duch płynnie podąża za kursorem myszy
	ghost_instance.global_position = ghost_instance.get_global_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if not is_building:
		return
		
	if event is InputEventMouseButton and event.is_pressed():
		# Lewy Przycisk Myszy - POSTAW OBIEKT
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_object()
			get_viewport().set_input_as_handled()
			
		# Prawy Przycisk Myszy - ANULUJ
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_building()
			get_viewport().set_input_as_handled()
			
	# Klawisz Escape (Twoja akcja Game_Pause) - ANULUJ
	elif event.is_action_pressed("Game_Pause"):
		_cancel_building()
		get_viewport().set_input_as_handled()

func start_building(scene_to_build: PackedScene, item_to_refund: ItemData) -> void:
	if is_building:
		_cancel_building() # Zabezpieczenie przed jednoczesnym budowaniem 2 rzeczy
		
	current_build_scene = scene_to_build
	refund_item = item_to_refund
	is_building = true
	
	# Tworzymy "ducha"
	ghost_instance = current_build_scene.instantiate()
	
	# Zmieniamy przezroczystość (modulate) na 50%, żeby wyglądał jak hologram
	if "modulate" in ghost_instance:
		var color = ghost_instance.modulate
		color.a = 0.5
		ghost_instance.modulate = color
		
	# BARDZO WAŻNE: Wyłączamy kolizje ducha, by nie odpychał/blokował gracza
	_disable_collisions(ghost_instance)
	
	# Dodajemy ducha do głównej sceny gry (świata)
	get_tree().current_scene.add_child(ghost_instance)

func _place_object() -> void:
	# Tworzymy właściwy, fizyczny obiekt
	var final_instance = current_build_scene.instantiate()
	final_instance.global_position = ghost_instance.global_position
	
	get_tree().current_scene.add_child(final_instance)
	print("BuilderComponent: Obiekt pomyślnie postawiony!")
	
	_cleanup()

func _cancel_building() -> void:
	# Skoro gracz anulował budowę, a ekwipunek "zjadł" przedmiot, musimy mu go oddać
	if player_inventory and refund_item:
		# Zakładam, że Twoje Inventory ma funkcję dodawania (np. add_item)
		# Jeśli u Ciebie nazywa się inaczej (np. insert_item), zmień poniższą linijkę
		player_inventory.add_item(refund_item, 1) 
		print("BuilderComponent: Anulowano budowę, zwrócono przedmiot.")
		
	_cleanup()

func _cleanup() -> void:
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	ghost_instance = null
	current_build_scene = null
	refund_item = null
	is_building = false

# Rekurencyjna funkcja wyłączająca wszystkie kolizje w drzewie "ducha"
func _disable_collisions(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.disabled = true
	for child in node.get_children():
		_disable_collisions(child)
