extends Area2D
class_name InteractableComponent

signal targeted
signal untargeted
signal interacted(interactor: Node)

@export var is_targeted: bool = false

# Możesz tu dodać np. Sprite "celownika", który jest domyślnie ukryty
@onready var highlight_sprite: Sprite2D = $HighlightSprite 

@export var outline_material: ShaderMaterial # Tutaj wrzucimy nasz materiał!


# --- NOWE ZMIENNE EXPORT ---
@export var target_sprite: Sprite2D
@export var target_collision: CollisionShape2D


# Zmienna przechowująca grafikę obiektu
var parent_sprite: Sprite2D

func _ready():
	if highlight_sprite:
		highlight_sprite.hide()
	
	# 1. PRZYPISANIE SPRITE'A
	# Jeśli ustawiłeś Sprite2D w Inspektorze, przypisujemy go
	if target_sprite != null:
		parent_sprite = target_sprite
	else:
		print("Uwaga: InteractableComponent nie ma przypisanego target_sprite!")
		
	# 2. KOPIOWANIE KOLIZJI
	# Jeśli ustawiłeś CollisionShape2D w Inspektorze, kopiujemy jego kształt do nas
	if target_collision != null:
		var my_own_collider = CollisionShape2D.new()
		my_own_collider.shape = target_collision.shape # Kopiujemy rozmiar i typ
		my_own_collider.transform = target_collision.transform # Kopiujemy przesunięcie
		
		# Dodajemy jako dziecko tego InteractableComponent
		call_deferred("add_child", my_own_collider)
	else:
		print("Uwaga: InteractableComponent nie ma przypisanego target_collision!")

# --- UNIWERSALNE FUNKCJE ZAZNACZANIA (Wywoływane TYLKO przez RayCast Gracza) ---
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
