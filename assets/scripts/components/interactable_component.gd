extends Area2D
class_name InteractableComponent

signal targeted
signal untargeted
signal interacted(interactor: Node)
signal collected(interactor: Node)

# --- NOWY KOD: Zmienna włączająca auto-wykrywanie (domyślnie true) ---
@export var auto_detect_type: bool = true
# --------------------------------------------------------------------

# --- NOWY KOD: Definicja typów interakcji (Enum) ---
enum TargetType {
	DEFAULT,     # (Domyślnie)
	ENEMY,       # (Wrogowie)
	ITEM,        # (Interakcje z przedmiotami)
	NPC,         # (Niewrogie NPC)
	OBJECT,      # (Postawione rzeczy/obiekty)
	PLAYER       # (Gracz)
}

# Eksportujemy enum, aby pojawiła się rozwijana lista w Inspektorze
@export var target_type: TargetType = TargetType.DEFAULT
# ---------------------------------------------------

# Możesz tu dodać np. Sprite "celownika", który jest domyślnie ukryty
@onready var highlight_sprite: Sprite2D = $HighlightSprite 

@export var is_targeted: bool = false

@export var outline_material: ShaderMaterial

@export var target_sprite: Node2D
@export var target_collision: CollisionShape2D

# Zmienna przechowująca grafikę obiektu
var parent_sprite: Node2D

func _ready():
	# Automatyczne ustawienie warstwy i sortowania
	z_index = GameLayers.INTERACTABLE_HIGHLIGHT
	
	if highlight_sprite:
		highlight_sprite.hide()
		
		# --- NOWY KOD: Auto-wykrywanie typu parenta przed ustawieniem tekstury ---
		if auto_detect_type:
			_detect_parent_type()
		# -------------------------------------------------------------------------
		
		# --- NOWY KOD: Wywołanie funkcji ustawiającej teksturę ---
		_setup_highlight_texture()
		# ---------------------------------------------------------
	
	# 1. PRZYPISANIE SPRITE'A
	# Jeśli ustawiłeś Sprite2D w Inspektorze, przypisujemy go
	if target_sprite != null:
		parent_sprite = target_sprite
	else:
		push_warning("Uwaga: InteractableComponent nie ma przypisanego target_sprite! Węzeł: ", name)
		
	# 2. KOPIOWANIE KOLIZJI
	# Jeśli ustawiłeś CollisionShape2D w Inspektorze, kopiujemy jego kształt do nas
	if target_collision != null:
		var my_own_collider = CollisionShape2D.new()
		my_own_collider.shape = target_collision.shape # Kopiujemy rozmiar i typ
		my_own_collider.transform = target_collision.transform # Kopiujemy przesunięcie
		
		# Dodajemy jako dziecko tego InteractableComponent
		call_deferred("add_child", my_own_collider)
	else:
		push_warning("Uwaga: InteractableComponent nie ma przypisanego target_collision! Węzeł: ", name)

# --- NOWY KOD: Funkcja automatycznie wykrywająca typ parenta ---
func _detect_parent_type():
	var parent = get_parent()
	if parent == null:
		return
		
	var p_name = parent.name.to_lower()
	
	# Sprawdzanie bazujące na nazwach widocznych na zdjęciu warstw (np. Enemy, ItemPickup, NPC)
	if parent.is_in_group("Enemy"):
		target_type = TargetType.ENEMY
	elif parent.is_in_group("ItemPickup"):
		target_type = TargetType.ITEM
	elif parent.is_in_group("NPC"):
		target_type = TargetType.NPC
	elif parent.is_in_group("PlacedObject"):
		target_type = TargetType.OBJECT
# ---------------------------------------------------------------

# --- NOWY KOD: Funkcja przypisująca odpowiednią teksturę ---
func _setup_highlight_texture():
	# UWAGA: Podmień "res://assets/.../targeters/" na Twoją dokładną ścieżkę z systemu plików,
	# którą widać w lewym dolnym rogu na zrzucie ekranu.
	match target_type:
		TargetType.ENEMY:
			highlight_sprite.texture = preload("res://assets/textures/samples_examples/targeters/red_targeter.png")
		TargetType.ITEM:
			highlight_sprite.texture = preload("res://assets/textures/samples_examples/targeters/violet_targeter.png")
		TargetType.NPC:
			highlight_sprite.texture = preload("res://assets/textures/samples_examples/targeters/green_targeter.png")
		TargetType.OBJECT:
			highlight_sprite.texture = preload("res://assets/textures/samples_examples/targeters/yellow_targeter.png")
		TargetType.PLAYER:
			highlight_sprite.texture = preload("res://assets/textures/samples_examples/targeters/blue_targeter.png")
# -----------------------------------------------------------


# --- UNIWERSALNE FUNKCJE ZAZNACZANIA (Wywoływane TYLKO przez RayCast Gracza) ---
func target():
	if not is_targeted:
		is_targeted = true
		targeted.emit()
		
		# Prosty efekt wizualny - pokazujemy celownik (lub zmieniamy kolor)
		if highlight_sprite:
			highlight_sprite.show()
		
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
		
		# WYŁĄCZANIE ZAZNACZENIA WIZUALNEGO
		if parent_sprite != null:
			parent_sprite.material = null # Czyścimy shader

## Ktoś nas wcisnął/użył
func interact(interactor: Node):
	interacted.emit(interactor)

## Funkcja wywoływana przez gracza przy wciśnięciu F
func collect_interaction(interactor: Node):
	collected.emit(interactor)
