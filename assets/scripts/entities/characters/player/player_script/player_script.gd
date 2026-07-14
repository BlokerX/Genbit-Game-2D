## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

#region Zmienne i Stałe Globalne

# --- STAŁE WEJŚCIA (Wyeliminowanie magicznych stringów) ---
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
# ----------------------------------------------------------

## Sygnał służący do spawnowania obiektów (pociski, wyrzucone przedmioty) bez wiedzy o LevelManagerze
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

## Sygnał wykonywany po skończonej inicjalizacji gracza
#signal setup_complete

#endregion

#region Podłączone komponenty indywidualne dla gracza

## Komponent ekwipunku gracza
@export var inventory : Inventory

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory

## Komponent budowania
@export var builder_component: BuilderComponent

#region Celownik / Skaner

### Aim component
@onready var aim_controller: PlayerAimController = $AimController

# Pamięta, z jakiego kontrolera gracz ostatnio korzystał
var is_using_mouse: bool = true

#endregion

#endregion

#region Obsługa przedmiotów w inventory

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")

var drop_hold_time: float = 0.0
## Czas w sekundach wymagany do wyrzucenia całego stacka
var time_required_for_full_stack: float = 0.5 

#endregion

# Pamięta, czy gracz trzyma przycisk ataku, żeby atakować seriami (ciągły atak)
var is_holding_attack: bool = false

#region Pociski

## Scena pocisku dla broni dystansowej
@export var projectile_scene: PackedScene
## Mnożnik siły wyrzucania przedmiotów
@export var throw_force_multiplier: float = 3.0
## Siła z jaką gracz popycha obiekty fizyczne
@export var push_force: float = 10.0

#endregion

#region Główne funkcje silnikowe

func _ready():
	# Inicjalizacja MovementComponent
	#movement_universal_script = preload("res://assets/scripts/entities/movement/special_instations/player_movement_component.tres")
	# Domyślne parametry:
	# moveSpeed = 450
	# accelerationMultiplayer = 5.0
	# decelerationMultiplayer = 0.825
	# Inicjalizacja MonitoredLifeStatsComponent
	#health_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_monitored_life_stats_component.tres")
	# Inicjalizacja InteractionAndAttackStatsComponent
	#interaction_and_attack_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_interaction_and_attack_stats_component.tres")
	
	# Gracz nie umiera na zawsze
	destroy_entity_after_die = false 
	
	# Health points bar initialization
	super()
	
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
	
	# Movement procedure
	velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2(horizontal, vertical))
	
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
	
	#region Nasłuchiwanie urządzenia wejścia
	
	# 1. Przełączanie urządzeń
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		is_using_mouse = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.2:
		is_using_mouse = false
	elif event is InputEventJoypadButton:
		is_using_mouse = false
	elif event is InputEventKey and event.is_pressed():
		if event.is_action(INPUT_AIM_LEFT) or event.is_action(INPUT_AIM_RIGHT) or event.is_action(INPUT_AIM_UP) or event.is_action(INPUT_AIM_DOWN):
			is_using_mouse = false
	
	#endregion
	
	#region Ustawienia celownika
	
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
	
	#endregion
	
	#region Obsługa interakcji i wydarzeń
	
	# --- ATAK / STAWIANIE OBIEKTU (LPM / Trigger na padzie) ---
	if event.is_action_pressed(INPUT_ATTACK):
		if builder_component and builder_component.is_building:
			# Jesteśmy w trybie budowy - próbujemy postawić obiekt
			if builder_component.try_place_object():
				inventory.consume_current_item() # Odejmujemy z ekwipunku
				builder_component.stop_building() # Wychodzimy z trybu budowy po postawieniu
		else:
			# Zwykły ciągły atak (jeśli nie budujemy)
			is_holding_attack = true
			
	elif event.is_action_released(INPUT_ATTACK):
		is_holding_attack = false
		
	# --- UŻYCIE PRZEDMIOTU / WEJŚCIE W TRYB BUDOWY ---
	if event.is_action_pressed(INPUT_USE_ITEM):
		print("--- DEBUG: Wciśnięto przycisk Użycia ---")
		
		# Jeśli już budujemy, ponowne wciśnięcie "Użyj" anuluje budowę
		if builder_component and builder_component.is_building:
			print("DEBUG: Anuluję budowę.")
			builder_component.stop_building()
			return 
			
		var _item = inventory.get_current_item()
		print("DEBUG: Przedmiot w ręce to: ", _item)
		
		# 1. Sprawdzamy czy to przedmiot do postawienia
		if _item is PlaceableItem:
			print("DEBUG: Przedmiot JEST stawialny (PlaceableItem)!")
			if builder_component:
				if _item is PlaceableItem:
					if _item.scene_path == null or _item.scene_path.is_empty():
						push_error("Przedmiot nie ma przypisanej sceny: ", _item.item_name)
						return
					var scene_resource = load(_item.scene_path)
					builder_component.start_building(scene_resource)
					print("DEBUG: Odpalono ducha!")
			else:
				push_error("BŁĄD KRYTYCZNY: Nie znaleziono węzła BuilderComponent w Graczu!")
			return # Przerywamy kod, żeby się nie leczyć skrzynią
			
		# 2. Sprawdzamy czy to mikstura/jedzenie (Zwykłe użycie)
		if interaction_and_attack_stats_script.can_attack():
			if _item is EatableItem or _item is UseableItem:
				if _item.affect_target(self):
					inventory.consume_current_item()
					interaction_and_attack_stats_script.reset_cooldown()

	# --- INTERAKCJA / ALTERNATYWNE ANULOWANIE BUDOWY ---
	if event.is_action_pressed(INPUT_INTERACT):
		if builder_component and builder_component.is_building:
			# Anulujemy budowę (jeśli gracz wolał wcisnąć PPM zamiast "Użyj")
			builder_component.stop_building()
			return 
			
		# Zwykła interakcja z otoczeniem
		if aim_controller.current_target != null:
			aim_controller.current_target.interact(self)
	
	# --- OBRACANIE OBIEKTU W TRYBIE BUDOWY ---
	if event.is_action_pressed(INPUT_ROTATE):
		if builder_component and builder_component.is_building:
			builder_component.rotate_object()
	
	# --- PAUZA ---
	if event.is_action_pressed("Game_Pause"):
		if builder_component and builder_component.is_building:
			builder_component.stop_building()
			get_viewport().set_input_as_handled() 
	
	# Respawn
	if event.is_action_pressed(INPUT_RESPAWN):
		call_deferred("respawn_sequence")
		print("Gracz się odrodził!")
	
	#endregion
	
	#region Sterowanie ekwipunkiem
	
	# Sterowanie ekwipunkiem
	for i in range(1, 10):
		if event.is_action_pressed(INPUT_INV_SLOT_PREFIX + str(i)):
			inventory.select_item(i - 1)
		
	if event.is_action_pressed(INPUT_INV_SCROLL_DOWN):
		inventory.scroll_inventory(1)
	elif event.is_action_pressed(INPUT_INV_SCROLL_UP):
		inventory.scroll_inventory(-1)
		
	#endregion

#endregion

#region Obsługa sygnałów

## Wywołuje się kiedy ekwipunek jest aktualizowany.
func on_inventory_update() :
	
	##region debug log
	#
	#print("================")
	#print("Inventory state:")
	#print("---")
	#var __item_name : String = "null"
	#var __item_durable : String = "null"
	#var __item_max_durable : String = "null"
	#var __item_stack_count : String = "null"
	#var __item_max_stack_count : String = "null"
	#var __item_is_stackable : String = "null"
	#if inventory.get_current_item() != null :
		#__item_name = inventory.get_current_item().item_name
		#__item_durable = str(inventory.get_current_item().durable)
		#__item_max_durable = str(inventory.get_current_item().max_durable)
		#__item_stack_count = str(inventory.get_current_item().item_stack_count)
		#__item_max_stack_count = str(inventory.get_current_item().item_max_stack_count)
		#__item_is_stackable = str(inventory.get_current_item().item_is_stackable)
	#print("Current item (slot number = " + str(inventory.current_item_index + 1) + " / " + str(inventory.max_items) + "): " + __item_name)
	#print("Durability of the item = " + __item_durable + " / " + __item_max_durable)
	#print("Is item stackable = " + __item_is_stackable)
	#print("Stack of the item = " + __item_stack_count + " / " + __item_max_stack_count)
	#print("---")
	#print("Items:")
	#for item in inventory.items :
		#if item != null :
			#print(item.item_name)
	#print("================")
	#
	##endregion
	
	var current_slot = inventory.get_current_slot()
	var current_item = inventory.get_current_item()
	
	# Aktualizacja ręki gracza (itemu w ręce)
	if current_item != null:
		# Jeśli slot nie jest pusty, wkładamy przedmiot do dłoni rycerza.
		held_item_visual.texture = current_item.item_icon
		held_item_visual.show() # Pokazujemy dłoń (item)
	else:
		# Jeśli slot jest pusty, czyścimy dłoń
		held_item_visual.texture = null
		held_item_visual.hide() # Ukrywamy, żeby nie było widać "niczego"
	
	# Podłączamy sygnał zepsucia do aktywnego przedmiotu
	if current_slot != null and not current_slot.is_empty():
		if not current_slot.item_broken.is_connected(_on_item_broken):
			current_slot.item_broken.connect(_on_item_broken)
	
	# Aktualizacja cooldownu z przedmiotu używalnego albo z pustych rąk
	if current_item is UseableItem:
		# Przekazujemy cooldown przedmiotu do statystyk gracza
		interaction_and_attack_stats_script.actual_cooldown = current_item.use_cooldown
		
		# PRZEKAZUJEMY DODATKOWE EFEKTY Z PRZEDMIOTU DO KOMPONENTU (zakładam, że tablica nazywa się 'effects')
		if "effects" in current_item:
			interaction_and_attack_stats_script.actual_extra_effects = current_item.effects
		
		if current_item is ItemWeapon:
			interaction_and_attack_stats_script.actual_attack_data = (current_item as ItemWeapon).attack_data
	else:
		# Jeśli to zwykły ItemData bez cooldownu, wracamy do limitu z pustych rąk
		interaction_and_attack_stats_script.actual_cooldown = interaction_and_attack_stats_script.hand_attack_cooldown
		interaction_and_attack_stats_script.actual_attack_data = interaction_and_attack_stats_script.hand_attack_data
		# Puste ręce nie mają dodatkowych efektów
		interaction_and_attack_stats_script.actual_extra_effects = []
	
	# --- ZABEZPIECZENIE TRYBU BUDOWANIA ---
	# Jeśli gracz zmieni slot lub wyrzuci przedmiot w trakcie trwania trybu budowy,
	# musimy mu ten tryb natychmiast anulować, żeby "duch" nie został na ekranie.
	if builder_component and builder_component.is_building:
		if not current_item is PlaceableItem:
			builder_component.stop_building()

## Wywołuje się podczas wyrzucania przedmiotu (fizyczne okodowanie Noda).
func _on_inventory_item_dropped(dropped_item_data: ItemData, drop_amount: int):
	if item_pickup_scene == null:
		print("Błąd: Brak przypisanej sceny item_pickup_scene w Graczu!")
		return
	
	var drop = item_pickup_scene.instantiate()
	drop.item_data = dropped_item_data
	drop.amount = drop_amount
	
	entity_spawn_requested.emit(drop, global_position)
	
	var drop_direction = Vector2.ZERO
	var drop_force = 0.0
	
	if is_using_mouse:
		# --- WYRZUT MYSZKĄ ---
		var mouse_global_pos = get_global_mouse_position()
		var dist_to_mouse = global_position.distance_to(mouse_global_pos)
		
		# 1. Kierunek: idealnie w stronę kursora (0 rozrzutu!)
		var aim_direction = global_position.direction_to(mouse_global_pos)
		if aim_direction == Vector2.ZERO:
			aim_direction = Vector2.DOWN
		
		drop_direction = aim_direction
		
		# 2. Siła: Ograniczamy maksymalny zasięg rzutu (np. do 150 pikseli)
		var max_throw_range = 150.0
		var actual_throw_distance = min(dist_to_mouse, max_throw_range)
		
		# Obliczamy siłę. Mnożnik zależy od fizyki przedmiotu. 
		# Jeśli nadal rzuca za daleko, zmniejsz 3.0 na 2.0 itd.
		drop_force = actual_throw_distance * throw_force_multiplier
		
		# Zabezpieczenie: minimalna siła, żeby przedmiot wyleciał spod nóg
		if drop_force < 50.0:
			drop_force = 50.0
		
		# Dodajemy bardzo minimalny rozrzut, żeby stacki ułożone w 1 miejscu nie nachodziły idealnie na siebie
		var spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
		drop_direction = (aim_direction + spread).normalized()
		
	else:
		# --- WYRZUT PADEM / KLAWIATURĄ ---
		# Pobieramy bazowy kierunek z celownika
		var aim_direction = aim_controller.aim_scanner.target_position.normalized()
		
		if aim_direction == Vector2.ZERO:
			aim_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		
		# W padzie rozrzut może być ciut większy i siła jest stała/losowa
		var spread = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		drop_direction = (aim_direction + spread).normalized()
		drop_force = randf_range(200.0, 300.0)
	
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

# --- FUNKCJA WALKI Z DYSTANSEM ---
func perform_attack() -> void:
	var _item = inventory.get_current_item()
	var target_enemy = aim_controller.get_target_node()
	
	if target_enemy != null:
		
		# Pobieramy dystans z naszej nowej funkcji
		var max_attack_distance = get_current_attack_range()
		if max_attack_distance <= 0.0:
			return # Mamy w ręku np. miksturę, więc nie atakujemy
			
		# --- Mierzenie dystansu do wroga ---
		var distance_to_enemy = global_position.distance_to(target_enemy.global_position)
		
		# --- Właściwy atak ---
		if distance_to_enemy <= max_attack_distance:
				
			if _item is ItemWeapon:
				# Różnicowanie logiki na podstawie typu broni
				if _item is ItemDistanceWeapon:
					print("Strzał z broni dystansowej!")
					if projectile_scene != null:
						# Zbieramy efekty
						var generated_effects = interaction_and_attack_stats_script.get_all_attack_effects()
						
						# Tworzymy pocisk
						var new_projectile = projectile_scene.instantiate()
						new_projectile.shooter = self
						new_projectile.global_position = global_position
						
						# Kierunek strzału (w stronę celu lub punktu celownika)
						var shoot_dir = global_position.direction_to(target_enemy.global_position)
						new_projectile.direction = shoot_dir
						new_projectile.effects_to_apply = generated_effects
						
						# Przekazujemy prędkość i czas życia. Zakładam, że w pliku 'projectile.gd'
						# masz zmienne np. 'speed' i 'lifetime'. Jeśli nazywają się inaczej, zmień je poniżej.
						if "speed" in new_projectile:
							new_projectile.speed = _item.projectile_speed
						elif "projectile_speed" in new_projectile:
							new_projectile.projectile_speed = _item.projectile_speed
					
						if "lifetime" in new_projectile:
							new_projectile.lifetime = _item.projectile_lifetime
				
						# Przekazujemy teksturę do Sprite2D wewnątrz pocisku
						var sprite = new_projectile.get_node_or_null("Sprite2D")
						if sprite != null and _item.projectile_texture != null:
							sprite.texture = _item.projectile_texture
						
						# EMISJA SYGNAŁU ZAMIAST LEVEL_MANAGERA
						entity_spawn_requested.emit(new_projectile, global_position)
					else:
						print("BŁĄD: Gracz próbuje strzelać, ale nie przypisano 'projectile_scene'!")
				else:
					
					# Sprawdzamy, czy ściana nie blokuje ataku
					if not aim_controller.has_line_of_sight(target_enemy):
						print("Atak zablokowany przez ścianę!")
						return
						
					print("Cios z broni białej!")
					interaction_and_attack_stats_script.execute_attack_on_target(target_enemy)
					# Zużywamy wytrzymałość broni po ataku
					inventory.consume_durability_of_the_item()
				
			elif _item == null:
				
				# Sprawdzamy, czy ściana nie blokuje ataku
				if not aim_controller.has_line_of_sight(target_enemy):
					print("Atak zablokowany przez ścianę!")
					return
					
				print("Gracz trafia z pięści!")
				interaction_and_attack_stats_script.execute_attack_on_target(target_enemy)
		else:
			print("Pudło! Wróg poza zasięgiem broni. (Dystans: ", distance_to_enemy, " / Max: ", max_attack_distance, ")")

# Zwraca aktualny zasięg ataku w zależności od przedmiotu
func get_current_attack_range() -> float:
	var _item = inventory.get_current_item()
	if _item is ItemWeapon:
		# Broń posiada mnożnik zasięgu (np. 1.0, 1.5) względem bazowego celownika (aim_distance)
		return aim_controller.aim_distance * _item.attack_data.max_range
	elif _item == null:
		# Puste ręce (pięści) posiadają swój własny zasięg w pikselach (np. 50), nie mnożymy tego!
		return float(interaction_and_attack_stats_script.get_total_range())
	else:
		return 0.0 # Przedmioty konsumpcyjne nie mają zasięgu ataku

#endregion
