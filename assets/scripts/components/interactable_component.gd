extends Area2D
class_name InteractableComponent
## Komponent interakcji i celowania obsługujący wykrywanie typu obiektu, obrys (highlight) oraz priorytety celownika.

signal targeted
signal untargeted
signal interacted(interactor: Node)
signal collected(interactor: Node)

# --- STAŁE PRIORYTETÓW CELOWANIA (Brak magicznych liczb) ---
const AIM_PRIORITY_NONE: int = 0
const AIM_PRIORITY_PLAYER: int = 1
const AIM_PRIORITY_ITEM: int = 2
const AIM_PRIORITY_PRIMARY: int = 3

## Zmienna włączająca auto-wykrywanie typu rodzica na starcie (domyślnie true).
@export var auto_detect_type: bool = true

## Definicja typów interakcji (Enum).
enum TargetType {
	DEFAULT,     ## Domyślny / Nieznany
	ENEMY,       ## Wrogowie
	ITEM,        ## Leżące przedmioty (ItemPickup)
	NPC,         ## Niewrogie postacie niezależne
	OBJECT,      ## Postawione obiekty / budynki / drzwi
	PLAYER       ## Gracz
}

## Typ celu używany do doboru koloru celownika oraz priorytetu wiązki lasera.
@export var target_type: TargetType = TargetType.DEFAULT

@onready var highlight_sprite: Sprite2D = $HighlightSprite
@export var is_targeted: bool = false
@export var outline_material: ShaderMaterial
@export var target_sprite: Node2D
@export var target_collision: CollisionShape2D

## Zmienna przechowująca grafikę obiektu nadrzędnego.
var parent_sprite: Node2D

func _ready() -> void:
	z_index = GameLayers.INTERACTABLE_HIGHLIGHT

	if highlight_sprite:
		highlight_sprite.hide()

	if auto_detect_type:
		_detect_parent_type()

	_setup_highlight_texture()

	# 1. PRZYPISANIE SPRITE'A
	if target_sprite != null:
		parent_sprite = target_sprite
	else:
		push_warning("Uwaga: InteractableComponent nie ma przypisanego target_sprite! Węzeł: ", name)

	# 2. KOPIOWANIE KOLIZJI
	if target_collision != null:
		var my_own_collider: CollisionShape2D = CollisionShape2D.new()
		my_own_collider.shape = target_collision.shape
		my_own_collider.transform = target_collision.transform
		call_deferred("add_child", my_own_collider)
	else:
		push_warning("Uwaga: InteractableComponent nie ma przypisanego target_collision! Węzeł: ", name)

## Automatycznie rozpoznaje typ obiektu nadrzędnego: najpierw po ścisłych klasach i grupach (SOLID),
## a jedynie w przypadku ich braku korzysta z awaryjnego sprawdzenia nazwy węzła.
func _detect_parent_type() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	# 1. Ścisłe rozpoznanie po klasach i grupach (chroni np. ItemPickup o nazwie "DoorKey" przed pomyleniem z drzwiami!)
	if parent.is_in_group("Enemy"):
		target_type = TargetType.ENEMY
		return
	if parent is ItemPickup or parent.is_in_group("ItemPickup"):
		target_type = TargetType.ITEM
		return
	if parent.is_in_group("NPC"):
		target_type = TargetType.NPC
		return
	if (
		parent is PlacedObject
		or parent is Door
		or parent.is_in_group("PlacedObject")
		or parent.is_in_group("Door")
		or parent.is_in_group("Object")
	):
		target_type = TargetType.OBJECT
		return
	if parent is PlayerCharacter or parent.is_in_group("Player"):
		target_type = TargetType.PLAYER
		return

	# 2. Awaryjny fallback po nazwie (tylko dla niestandardowych węzłów bez przypisanej grupy/klasy w edytorze)
	var p_name: String = parent.name.to_lower()
	if p_name.contains("enemy"):
		target_type = TargetType.ENEMY
	elif p_name.contains("item") or p_name.contains("pickup"):
		target_type = TargetType.ITEM
	elif p_name.contains("npc"):
		target_type = TargetType.NPC
	elif p_name.contains("door") or p_name.contains("object"):
		target_type = TargetType.OBJECT
	elif p_name.contains("player"):
		target_type = TargetType.PLAYER

## Przypisuje odpowiednią teksturę znacznika celowania dla danego typu obiektu.
func _setup_highlight_texture() -> void:
	if highlight_sprite == null:
		return
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

# =========================================================================
# METODY EKSPERCKIE DLA SYSTEMU CELOWANIA (SOLID - Information Expert / OCP)
# =========================================================================

## Zwraca priorytet przyciągania wiązki celownika (3 = Wrogowie/NPC/Obiekty, 2 = Przedmioty, 1 = Gracz, 0 = Brak).
func get_aim_priority() -> int:
	if target_type == TargetType.DEFAULT:
		_detect_parent_type()

	match target_type:
		TargetType.ENEMY, TargetType.NPC, TargetType.OBJECT:
			return AIM_PRIORITY_PRIMARY
		TargetType.ITEM:
			return AIM_PRIORITY_ITEM
		TargetType.PLAYER:
			return AIM_PRIORITY_PLAYER
	return AIM_PRIORITY_NONE

## Zwraca true, jeśli obiekt stanowi twardą przeszkodę (budynek, skrzynia, drzwi) zatrzymującą przebijanie lasera.
func is_hard_aim_blocker() -> bool:
	if target_type == TargetType.ITEM:
		return false
	if target_type == TargetType.OBJECT:
		return true
	var parent: Node = get_parent()
	if parent == null:
		return false
	return (
		parent is PlacedObject
		or parent is Door
		or parent.is_in_group("PlacedObject")
		or parent.is_in_group("Door")
		or parent.is_in_group("Object")
	)

## Zwraca true, jeśli właścicielem tego komponentu jest przeciwnik.
func is_enemy_target() -> bool:
	if target_type == TargetType.ENEMY:
		return true
	var parent: Node = get_parent()
	return parent != null and parent.is_in_group("Enemy")

## Zwraca true, jeśli właścicielem tego komponentu jest postawiony obiekt (np. skrzynia, barykada).
func is_building_target() -> bool:
	var parent: Node = get_parent()
	return parent != null and parent is PlacedObject

# --- UNIWERSALNE FUNKCJE ZAZNACZANIA (Wywoływane przez RayCast Gracza) ---
func target() -> void:
	if not is_targeted:
		is_targeted = true
		targeted.emit()

		if highlight_sprite:
			highlight_sprite.show()

		if parent_sprite != null and outline_material != null:
			parent_sprite.material = outline_material

func untarget() -> void:
	if is_targeted:
		is_targeted = false
		untargeted.emit()

		if highlight_sprite:
			highlight_sprite.hide()

		if parent_sprite != null:
			parent_sprite.material = null

## Wywoływane przy interakcji z obiektem (np. otwarcie skrzyni lub rozmowa z NPC).
func interact(interactor: Node) -> void:
	interacted.emit(interactor)

## Wywoływane przy podnoszeniu przedmiotu lub zbieraniu postawionego obiektu (klawisz F).
func collect_interaction(interactor: Node) -> void:
	collected.emit(interactor)
