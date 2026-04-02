extends Area2D
class_name InteractableComponent

signal targeted
signal untargeted
signal interacted(interactor: Node)

@export var is_targeted: bool = false

# Możesz tu dodać np. Sprite "celownika", który jest domyślnie ukryty
@onready var highlight_sprite: Sprite2D = $HighlightSprite 

@export var outline_material: ShaderMaterial # Tutaj wrzucimy nasz materiał!

# Zmienna przechowująca grafikę obiektu
var parent_sprite: Sprite2D

func _ready():
	# Podpinamy wbudowane sygnały Godota dla myszki
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if highlight_sprite:
		highlight_sprite.hide()
		
	
	# Przeszukujemy dzieci naszego rodzica (czyli nasze rodzeństwo)
	for child in get_parent().get_children():
		
		# 1. Szukamy grafiki (to już mieliśmy)
		if child is Sprite2D:
			parent_sprite = child
		
		# 2. NOWE: Szukamy istniejącej kolizji i kopiujemy ją do nas!
		elif child is CollisionShape2D:
			var my_own_collider = CollisionShape2D.new()
			my_own_collider.shape = child.shape # Kopiujemy ten sam rozmiar i kształt
			my_own_collider.transform = child.transform # Kopiujemy to samo przesunięcie
			
			# call_deferred bezpiecznie dodaje nowy węzeł do drzewa po załadowaniu sceny
			call_deferred("add_child", my_own_collider)

# --- OBSŁUGA MYSZKI ---
func _on_mouse_entered():
	target()

func _on_mouse_exited():
	untarget()

# --- UNIWERSALNE FUNKCJE ZAZNACZANIA (Dla myszki i Pada) ---
func target():
	if not is_targeted:
		is_targeted = true
		targeted.emit()
		
		# Prosty efekt wizualny - pokazujemy celownik (lub zmieniamy kolor)
		if highlight_sprite:
			highlight_sprite.show()
		else:
			get_parent().modulate = Color(1.5, 1.5, 1.5) # Podświetlenie rodzica
		
		# WŁĄCZANIE ZAZNACZENIA WIZUALNEGO
		if parent_sprite != null and outline_material != null:
			parent_sprite.material = outline_material

func untarget():
	if is_targeted:
		is_targeted = false
		untargeted.emit()
		
		# Ukrywamy celownik / resetujemy kolor
		if highlight_sprite:
			highlight_sprite.hide()
		else:
			get_parent().modulate = Color(1.0, 1.0, 1.0)
		
		# WYŁĄCZANIE ZAZNACZENIA WIZUALNEGO
		if parent_sprite != null:
			parent_sprite.material = null # Czyścimy shader

# Ktoś nas wcisnął/użył
func interact(interactor: Node):
	interacted.emit(interactor)

func _input_event(viewport, event, shape_idx):
	# Jeśli obiekt jest kliknięty lewym przyciskiem myszy
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		# Uwaga: Musimy zdobyć referencję do gracza.
		# Najlepiej np. wyszukać go w grupie "Player"
		var player = get_tree().get_first_node_in_group("Player")
		if player != null:
			interact(player)
