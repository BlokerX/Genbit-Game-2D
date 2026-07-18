## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

#region STAŁE WEJŚCIA (Wyeliminowanie magicznych stringów)

const INPUT_LEFT = "Left"
const INPUT_RIGHT = "Right"
const INPUT_UP = "Up"
const INPUT_DOWN = "Down"

const INPUT_AIM_LEFT = "AimLeft"
const INPUT_AIM_RIGHT = "AimRight"
const INPUT_AIM_UP = "AimUp"
const INPUT_AIM_DOWN = "AimDown"

const INPUT_DROP_ITEM = "DropItem"
const INPUT_ATTACK = "Attack"
const INPUT_USE_ITEM = "UseItemButton"
const INPUT_INTERACT = "Interact"
const INPUT_RESPAWN = "RespawnButton"
const INPUT_TOGGLE_ENEMY_PRIO = "ToggleEnemyPriority"

const INPUT_INV_SLOT_PREFIX = "InventorySlot"
const INPUT_INV_SCROLL_UP = "InventoryScrollUp"
const INPUT_INV_SCROLL_DOWN = "InventoryScrollDown"

## Przycisk obracania obiektów budowlanych (musisz go dodać w Input Map!)
const INPUT_ROTATE = "RotateBuilding"
#endregion

#region Signals

## Sygnał służący do spawnowania obiektów (pociski, wyrzucone przedmioty) bez wiedzy o LevelManagerze
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

# ## Sygnał wykonywany po skończonej inicjalizacji gracza
#signal setup_complete

#endregion

#region Podłączone komponenty indywidualne dla gracza

## Komponent obsługujący wykonywanie ataków
@export var attack_component: AttackComponent

## Komponent ekwipunku gracza
@export var inventory : Inventory

## Komponent budowania
@export var builder_component: BuilderComponent

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory

#endregion

#region Komponent Celownik / Skaner

### Aim component
@onready var aim_controller: PlayerAimController = $AimController

# Pamięta, z jakiego kontrolera gracz ostatnio korzystał
var is_using_mouse: bool = true

#endregion

#region Obsługa przedmiotów w inventory

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")

var drop_hold_time: float = 0.0
## Czas w sekundach wymagany do wyrzucenia całego stacka
var time_required_for_full_stack: float = 0.5 

## Przechowuje referencję do ostatnio podłączonego slotu, aby zapobiec wyciekom sygnałów
var last_connected_slot = null

@export_group("Throw Settings")
@export var max_throw_range: float = 150.0
@export var min_throw_force: float = 50.0
@export var pad_throw_force_min: float = 200.0
@export var pad_throw_force_max: float = 300.0
@export var drop_push_force: float = 20.0
@export var throw_force_multiplier: float = 3.0

#endregion

# Pamięta, czy gracz trzyma przycisk ataku, żeby atakować seriami (ciągły atak)
var is_holding_attack: bool = false

#region Pchnięcie

## Siła z jaką gracz popycha obiekty fizyczne
@export var push_force: float = 10.0

#endregion

#region System Stanów Gracza

enum PlayerState { DEFAULT, BUILDING}
var current_state: PlayerState = PlayerState.DEFAULT

#endregion

#region Główne funkcje silnikowe

func _ready():
	# ZABEZPIECZENIE
	# Jeśli zapomniano dodać skrypty w Inspektorze.
	# Jeśli coś jest null, to znaczy, że zapomniałeś podpiąć w edytorze
	assert(movement_universal_script != null, "Brak komponentu ruchu!")
	assert(health_stats_script != null, "Brak komponentu statystyk życia!")
	assert(interaction_and_attack_stats_script != null, "Brak komponentu interakcji i ataku!")
	
	# Gracz nie umiera na zawsze
	destroy_entity_after_die = false 
	
	# Health points bar initialization
	super()
	
	# Przekazywanie sygnału spawnowania pocisku wyżej, do menedżera mapy
	if attack_component:
		attack_component.spawn_projectile_requested.connect(
			func(node, pos): entity_spawn_requested.emit(node, pos)
		)
	
	#region Linkowanie zdarzeń
	if inventory:
		inventory.inventory_updated.connect(on_inventory_update)
		on_inventory_update()
		inventory.item_dropped.connect(_on_inventory_item_dropped)
	#endregion
	
	#setup_complete.emit()

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)
	
	#region Move Procedure
	
	# Movement inputs
	var horizontal := Input.get_axis(INPUT_LEFT, INPUT_RIGHT)
	var vertical := Input.get_axis(INPUT_UP, INPUT_DOWN)
	
	# Movement procedure - bezpieczne wywołanie
	if movement_universal_script != null:
		velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2(horizontal, vertical))
	else:
		velocity = Vector2.ZERO # Jeśli z jakiegoś powodu komponentu nadal nie ma, po prostu stoimy
	
	# Set sprite orientation
	if horizontal < 0 :
		if character_sprite.flip_h != false :
			character_sprite.flip_h = false
	elif horizontal > 0 :
		if character_sprite.flip_h != true :
			character_sprite.flip_h = true
	
	
	move_and_slide()
	
	# D_E_B_U_G
	#print("Monitor prędkości gracza: ", velocity)
	
	#endregion
	
	# Obsługa celowania skanerem - przekazujemy mu info czy to myszka i jaki mamy zasięg!
	var attack_range = get_current_attack_range()
	aim_controller.process_aiming(is_using_mouse, attack_range)
	# Obsługa popychania TODO
	_handle_pushing()
	# Obsługa wyrzucania itemów
	_handle_dropping(delta)
	
	# Zawsze aktualizujemy licznik cooldownu (wyciągnięte na górę dla porządku)
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
	
	# Zawsze aktualizujemy licznik cooldownu (bezpieczne wywołanie)
	if interaction_and_attack_stats_script != null:
		interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		
		# Jeśli gracz trzyma przycisk ataku i skończył się cooldown -> wykonaj uderzenie!
		if is_holding_attack and interaction_and_attack_stats_script.can_attack():
			perform_attack()

func _handle_pushing() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * push_force)

func _handle_dropping(delta: float) -> void:
	if Input.is_action_pressed(INPUT_DROP_ITEM):
		drop_hold_time += delta
		if drop_hold_time >= time_required_for_full_stack:
			inventory.drop_current_item(true)
			drop_hold_time = 0.0
	
	if Input.is_action_just_released(INPUT_DROP_ITEM):
		if drop_hold_time > 0.0 and drop_hold_time < time_required_for_full_stack:
			inventory.drop_current_item(false)
		drop_hold_time = 0.0

# --- WYŁAPYWANIE AKCJI BEZ PRZEBIJANIA UI ---
func _unhandled_input(event: InputEvent) -> void:
	
	# Detekcja typu urządzenia wejściowego
	_detect_input_device(event)
	
	# 1. Globalne inputy (pauza, ekwipunek, priorytety) - działają zawsze, niezależnie od stanu
	if _handle_global_inputs(event):
		return
	
	# 2. Inputy zależne od tego, co gracz aktualnie robi
	match current_state:
		PlayerState.DEFAULT:
			_handle_default_inputs(event)
		PlayerState.BUILDING:
			_handle_building_inputs(event)

#region Methods sections

func _detect_input_device(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		is_using_mouse = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.2:
		is_using_mouse = false
	elif event is InputEventJoypadButton:
		is_using_mouse = false
	elif event is InputEventKey and event.is_pressed():
		if event.is_action(INPUT_AIM_LEFT) or event.is_action(INPUT_AIM_RIGHT) or event.is_action(INPUT_AIM_UP) or event.is_action(INPUT_AIM_DOWN):
			is_using_mouse = false

func _handle_global_inputs(event: InputEvent) -> bool:
	#region Sterowanie priorytetowe
	
	# PAUZA
	if event.is_action_pressed("Game_Pause"):
		if current_state == PlayerState.BUILDING:
			_cancel_building()
			get_viewport().set_input_as_handled()
		return true
		
	# RESPAWN
	if event.is_action_pressed(INPUT_RESPAWN):
		call_deferred("respawn_sequence")
		print("Gracz się odrodził!")
		return true
	
	#endregion
	
	#region Zarządzanie zachowaniem celownika
	
	# --- PRZEŁĄCZANIE TRYBU PRIORYTETU WROGA ---
	if event.is_action_pressed(INPUT_TOGGLE_ENEMY_PRIO):
		aim_controller.auto_enemy_selector = !aim_controller.auto_enemy_selector
		aim_controller.auto_lock_closest_enemy = !aim_controller.auto_lock_closest_enemy
		
		# Opcjonalnie: Wyświetlamy informację w konsoli (później możesz to podpiąć pod jakiś napis na ekranie/UI)
		if aim_controller.auto_enemy_selector:
			print("Auto-Enemy Selector With Locking Closest Enemy: WŁĄCZONY")
		else:
			print("Auto-Enemy Selector With Locking Closest Enemy: WYŁĄCZONY")
			
			# Jeśli wyłączyliśmy tryb, a celownik trzymał wroga "na siłę", warto zresetować celownik:
			aim_controller.clear_gamepad_target()
		return true
	
	#endregion
	
	#region Sterowanie ekwipunkiem
	
	# Sterowanie ekwipunkiem
	for i in range(1, 10):
		if event.is_action_pressed(INPUT_INV_SLOT_PREFIX + str(i)):
			inventory.select_item(i - 1)
			return true
		
	if event.is_action_pressed(INPUT_INV_SCROLL_DOWN):
		inventory.scroll_inventory(1)
		return true
	elif event.is_action_pressed(INPUT_INV_SCROLL_UP):
		inventory.scroll_inventory(-1)
		return true
		
	#endregion
	
	# w przypadku nieodczytania sygnału wejścia z listy
	return false

func _handle_default_inputs(event: InputEvent) -> void:
	# ATAK
	if event.is_action_pressed(INPUT_ATTACK):
		is_holding_attack = true
	elif event.is_action_released(INPUT_ATTACK):
		is_holding_attack = false
		
	# INTERAKCJA
	if event.is_action_pressed(INPUT_INTERACT):
		if aim_controller.current_target != null:
			aim_controller.current_target.interact(self)

	# UŻYCIE PRZEDMIOTU (lub wejście w tryb budowy)
	if event.is_action_pressed(INPUT_USE_ITEM):
		var _item = inventory.get_current_item()
		if _item != null and _item.data != null:
			var _item_data = _item.data 
			# Sprawdzamy czy to przedmiot do postawienia
			if _item_data is PlaceableItem:
				_start_building(_item_data)
			# Zwykłe użycie
			elif interaction_and_attack_stats_script.can_attack():
				if _item_data is EatableItem:
					if _item_data.affect_target(self):
						inventory.consume_current_item()
						interaction_and_attack_stats_script.reset_cooldown()

func _handle_building_inputs(event: InputEvent) -> void:
	# W trybie budowy atak = postawienie obiektu
	if event.is_action_pressed(INPUT_ATTACK):
		if builder_component.try_place_object():
			inventory.consume_current_item()
			_cancel_building() # Wychodzimy z trybu budowy po udanym postawieniu
	
	# Obracanie obiektu
	if event.is_action_pressed(INPUT_ROTATE):
		builder_component.rotate_object()

	# Anulowanie budowy (PPM lub ponowne wciśnięcie przycisku użycia)
	if event.is_action_pressed(INPUT_INTERACT) or event.is_action_pressed(INPUT_USE_ITEM):
		_cancel_building()

func _start_building(item_data: PlaceableItem) -> void:
	if not builder_component:
		push_error("BŁĄD KRYTYCZNY: Nie znaleziono węzła BuilderComponent w Graczu!")
		return
	if item_data.scene_path == null or item_data.scene_path.is_empty():
		push_error("Przedmiot nie ma przypisanej sceny: ", item_data.item_name)
		return
		
	var scene_resource = load(item_data.scene_path)
	builder_component.start_building(scene_resource)
	
	# ZMIANA STANU GRACZA NA BUDOWANIE
	current_state = PlayerState.BUILDING
	is_holding_attack = false # Na wszelki wypadek resetujemy trzymanie ataku
	print("DEBUG: Wszedłem w stan BUILDING i odpaliłem ducha!")

func _cancel_building() -> void:
	if builder_component:
		builder_component.stop_building()
	# POWRÓT DO STANU DOMYŚLNEGO
	current_state = PlayerState.DEFAULT
	print("DEBUG: Anulowano budowę, wróciłem do stanu DEFAULT.")

#endregion

#endregion

#region Obsługa sygnałów

## Wywołuje się kiedy ekwipunek jest aktualizowany.
func on_inventory_update() :
	var current_slot = inventory.get_current_slot()
	var current_item = inventory.get_current_item()
	
	# Aktualizacja ręki gracza (itemu w ręce)
	if current_item != null:
		# Jeśli slot nie jest pusty, wkładamy przedmiot do dłoni rycerza.
		held_item_visual.texture = current_item.data.item_icon
		held_item_visual.show() # Pokazujemy dłoń (item)
	else:
		# Jeśli slot jest pusty, czyścimy dłoń
		held_item_visual.texture = null
		held_item_visual.hide() # Ukrywamy, żeby nie było widać "niczego"
	
	
	# 1. ODPINANIE STAREGO SYGNAŁU
	if last_connected_slot != null and not last_connected_slot.is_empty():
		if last_connected_slot.item.item_broken.is_connected(_on_item_broken):
			last_connected_slot.item.item_broken.disconnect(_on_item_broken)

	# 2. PODŁĄCZANIE NOWEGO SYGNAŁU
	if current_slot != null and not current_slot.is_empty():
		if not current_slot.item.item_broken.is_connected(_on_item_broken):
			current_slot.item.item_broken.connect(_on_item_broken)
		last_connected_slot = current_slot
	else:
		last_connected_slot = null
	
	
	#Aktualizacja cooldownu z przedmiotu używalnego albo z pustych rąk
	if current_item != null and current_item.data is UseableItem:
		var useable_data = current_item.data as UseableItem
		
		# Teraz pobieramy statystyki bezpiecznie z useable_data
		interaction_and_attack_stats_script.actual_cooldown = useable_data.use_cooldown
		
		# PRZEKAZUJEMY DODATKOWE EFEKTY Z PRZEDMIOTU DO KOMPONENTU
		if "effects" in useable_data:
			interaction_and_attack_stats_script.actual_extra_effects = useable_data.effects
		
		if useable_data is ItemWeapon:
			interaction_and_attack_stats_script.actual_attack_data = useable_data.attack_data
	else:
		# Jeśli to zwykły ItemData bez cooldownu, wracamy do limitu z pustych rąk
		interaction_and_attack_stats_script.actual_cooldown = interaction_and_attack_stats_script.hand_attack_cooldown
		interaction_and_attack_stats_script.actual_attack_data = interaction_and_attack_stats_script.hand_attack_data
		# Puste ręce nie mają dodatkowych efektów
		interaction_and_attack_stats_script.actual_extra_effects = []
	
	# --- ZABEZPIECZENIE TRYBU BUDOWANIA ---
	# Jeśli gracz zmieni slot lub wyrzuci przedmiot w trakcie trwania trybu budowy
	if current_state == PlayerState.BUILDING:
		if current_item == null or not current_item.data is PlaceableItem:
			_cancel_building()

## Wywołuje się podczas wyrzucania przedmiotu (fizyczne okodowanie Noda).
func _on_inventory_item_dropped(dropped_instance: ItemInstance, is_thrown: bool):
	if item_pickup_scene == null:
		print("Błąd: Brak przypisanej sceny item_pickup_scene w Graczu!")
		return
	
	var drop = item_pickup_scene.instantiate()
	drop.item = dropped_instance # Przekazujemy paczkę do przedmiotu 3D/2D
	
	entity_spawn_requested.emit(drop, global_position)
	
	var drop_direction = Vector2.ZERO
	var drop_force = 0.0
	
	if is_thrown:
		if is_using_mouse:
			# --- WYRZUT MYSZKĄ ---
			var mouse_global_pos = get_global_mouse_position()
			var dist_to_mouse = global_position.distance_to(mouse_global_pos)
			
			var aim_direction = global_position.direction_to(mouse_global_pos)
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2.DOWN
			
			var actual_throw_distance = min(dist_to_mouse, max_throw_range)
			drop_force = actual_throw_distance * throw_force_multiplier
			
			if drop_force < min_throw_force:
				drop_force = min_throw_force
			
			var spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
			drop_direction = (aim_direction + spread).normalized()
			
		else:
			# --- WYRZUT PADEM / KLAWIATURĄ ---
			var aim_direction = aim_controller.aim_scanner.target_position.normalized()
			
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			
			var spread = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			drop_direction = (aim_direction + spread).normalized()
			drop_force = randf_range(pad_throw_force_min, pad_throw_force_max)
	else:
		# --- DELIKATNE UPUSZCZENIE Z CRAFTINGU ---
		drop_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		drop_force = drop_push_force # Ledwo zauważalne popchnięcie by odseparować leżące obiekty
	
	# Ponieważ nasz upuszczany przedmiot to RigidBody2D, traktujemy go fizycznie
	if drop is RigidBody2D:
		drop.apply_central_impulse(drop_direction * drop_force)

## Wywołuje się gdy przedmiot jest niszczony.
func _on_item_broken(broken_item_name: String):
	print("Twój przedmiot zniszczył się: ", broken_item_name)
	# Tutaj możesz dodać np.: $AudioStreamPlayer.play()

# Nadpisanie bazowej funkcji z CharacterEntity
func respawn_sequence() -> void:
	# 1. Odpalamy całą logikę bazową (leczenie, zerowanie prędkości, usuwanie efektów)
	super() 
	
	print("Gracz: Inicjalizuję respawn powiązany z mapą...")
	
	# 2. Przekazanie obsługi położenia do LevelManagera, 
	# abyśmy przenieśli się też wewnątrz węzłów pokoi, a nie tylko wizualnie
	var level_manager = get_tree().get_first_node_in_group("LevelManager")
	if level_manager:
		if level_manager.has_method("handle_player_respawn"):
			level_manager.handle_player_respawn(self)
	else:
		push_warning("Nie znaleziono LevelManagera podczas respawnu!")

#endregion

#region System ataku

## Obsługa ataku
func perform_attack() -> void:
	var _item = inventory.get_current_item()
	var _item_data = _item.data if _item != null else null 
	
	var target_enemy = aim_controller.get_target_node()
	if target_enemy == null:
		return
		
	var max_attack_distance = get_current_attack_range()
	if max_attack_distance <= 0.0:
		return 
		
	var distance_to_enemy = global_position.distance_to(target_enemy.global_position)
	var has_los = aim_controller.has_line_of_sight(target_enemy)

	if attack_component:
		# Zlecamy brudną robotę komponentowi
		var attack_successful = attack_component.execute_attack(
			self,
			target_enemy,
			_item_data,
			interaction_and_attack_stats_script,
			distance_to_enemy,
			max_attack_distance,
			has_los
		)
		
		# Jeśli atak się udał fizycznie i używaliśmy broni, konsumujemy wytrzymałość
		if attack_successful and _item_data != null and _item_data is ItemWeapon:
			inventory.consume_durability_of_the_item()

# Zwraca aktualny zasięg ataku w zależności od przedmiotu
func get_current_attack_range() -> float:
	var _item = inventory.get_current_item()
	# Wyciągamy dane z pudełka
	var _item_data = _item.data if _item != null else null
	
	if _item_data is ItemWeapon: # Używamy _item_data!
		return aim_controller.aim_distance * _item_data.attack_data.max_range
	elif _item_data == null:
		return float(interaction_and_attack_stats_script.get_total_range())
	else:
		return 0.0

#endregion
