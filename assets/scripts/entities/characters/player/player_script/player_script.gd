## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

#region Podłączone komponenty indywidualne dla gracza

## Komponent ekwipunku gracza
@export var inventory : Inventory

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory
	
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
	movement_universal_script = preload("res://assets/scripts/entities/movement/special_instations/player_movement_component.tres")
	# Domyślne parametry:
	# moveSpeed = 450
	# accelerationMultiplayer = 5.0
	# decelerationMultiplayer = 0.825
	
	# Inicjalizacja MonitoredStatsComponent
	health_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_monitored_life_stats_component.tres")
	
	# Inicjalizacja InteractionAndAttackStatsComponent
	interaction_and_attack_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_interaction_and_attack_stats_component.tres")
	
	# Health points bar initialization
	super()
	
	#region Linkowanie zdarzeń
	inventory.inventory_updated.connect(on_inventory_update)
	on_inventory_update()

	inventory.item_dropped.connect(_on_inventory_item_dropped)
	#endregion

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)
	
	#region Move Procedure
	
	# Movement inputs
	var horizontal := Input.get_axis("Left", "Right")
	var vertical := Input.get_axis("Up","Down")
	
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
	if Input.is_action_pressed("DropItem"):
		drop_hold_time += delta
		if drop_hold_time >= time_required_for_full_stack:
			inventory.drop_current_item(true)
			drop_hold_time = 0.0
	
	if Input.is_action_just_released("DropItem"):
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
		if event.is_action("AimLeft") or event.is_action("AimRight") or event.is_action("AimUp") or event.is_action("AimDown"):
			is_using_mouse = false
	
	#endregion
	
	#region Ustawienia celownika
	
	# --- PRZEŁĄCZANIE TRYBU PRIORYTETU WROGA ---
	if event.is_action_pressed("ToggleEnemyPriority"):
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
	
	# Akcja ataku (Pamiętamy, czy wciśnięto przycisk)
	if event.is_action_pressed("Attack"):
		is_holding_attack = true
	elif event.is_action_released("Attack"):
		is_holding_attack = false
		
	# Użycie przedmiotu (Tylko Leczenie/Konsumpcja)
	if event.is_action_pressed("UseItemButton") and interaction_and_attack_stats_script.can_attack():
		var _item = inventory.get_current_item()
		if _item is HealingItem:
			if _item.affect_target(self):
				inventory.consume_current_item()
				interaction_and_attack_stats_script.reset_cooldown()

	# Interakcja
	if event.is_action_pressed("Interact"):
		if aim_controller.current_target != null:
			aim_controller.current_target.interact(self)
	
	# Respawn
	if event.is_action_pressed("RespawnButton"):
		respawn()
		print("Gracz się odrodził!")
	
	#endregion
	
	#region Sterowanie ekwipunkiem
	
	# STEROWANIE EKWIPUNKIEM (Zainicjowane przez gracza)
	if event.is_action_pressed("InventorySlot1"):
		inventory.select_item(0)
	elif event.is_action_pressed("InventorySlot2"):
		inventory.select_item(1)
	elif event.is_action_pressed("InventorySlot3"):
		inventory.select_item(2)
	elif event.is_action_pressed("InventorySlot4"):
		inventory.select_item(3)
	elif event.is_action_pressed("InventorySlot5"):
		inventory.select_item(4)
	elif event.is_action_pressed("InventorySlot6"):
		inventory.select_item(5)
	elif event.is_action_pressed("InventorySlot7"):
		inventory.select_item(6)
	elif event.is_action_pressed("InventorySlot8"):
		inventory.select_item(7)
	elif event.is_action_pressed("InventorySlot9"):
		inventory.select_item(8)
		
	elif event.is_action_pressed("InventoryScrollDown"):
		inventory.scroll_inventory(1)
	elif event.is_action_pressed("InventoryScrollUp"):
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
	if current_item != null and not current_item.item_broken.is_connected(_on_item_broken):
		current_item.item_broken.connect(_on_item_broken)
	
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

## Wywołuje się podczas wyrzucania przedmiotu (fizyczne okodowanie Noda).
func _on_inventory_item_dropped(dropped_item_data: ItemData):
	if item_pickup_scene == null:
		print("Błąd: Brak przypisanej sceny item_pickup_scene w Graczu!")
		return
	
	var drop = item_pickup_scene.instantiate()
	drop.item_data = dropped_item_data
	
	# --- Fizyczne wyrzucenie przedmiotu ---
	get_tree().current_scene.add_child(drop)
	# Ustawiamy punkt startowy na środek gracza
	drop.global_position = global_position
	
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

#endregion

#region System ataku

# --- FUNKCJA WALKI Z DYSTANSEM ---
func perform_attack() -> void:
	var _item = inventory.get_current_item()
	var target_enemy = aim_controller.get_enemy_target()
	
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
				if _item.is_ranged:
					print("Strzał z broni dystansowej!")
					if projectile_scene != null:
						# Zbieramy efekty
						var generated_effects = interaction_and_attack_stats_script.get_all_attack_effects()
						
						# Tworzymy pocisk
						var new_projectile = projectile_scene.instantiate()
						new_projectile.global_position = global_position
						
						# Kierunek strzału (w stronę celu lub punktu celownika)
						var shoot_dir = global_position.direction_to(target_enemy.global_position)
						new_projectile.direction = shoot_dir
						new_projectile.effects_to_apply = generated_effects
						
						# TODO przypisanie do sceny
						get_parent().add_child(new_projectile)
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
