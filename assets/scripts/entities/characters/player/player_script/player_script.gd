## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

#region Podłączone komponenty

## Komponent ekwipunku gracza
@export var inventory : Inventory

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory

#endregion

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")


#region Skaner / Celownik

@onready var aim_scanner: RayCast2D = $AimScanner

## Zasięg celownika
@export var aim_distance: float = 200.0


## Przechowujemy aktualnie namierzony obiekt przez celownik
var current_gamepad_target: InteractableComponent = null

# Pamięta, z jakiego kontrolera gracz ostatnio korzystał
var is_using_mouse: bool = true

#endregion

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
	interaction_and_attack_stats_script.hand_damage = 10
	interaction_and_attack_stats_script.hand_cooldown = 1.0
	
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
	
	# NOWE: System popychania fizycznych przedmiotów! ??
	var push_force = 10.0 # Zmień tę wartość, żeby przedmioty były lżejsze/cięższe
	
	# Sprawdzamy wszystkie obiekty, w które gracz właśnie uderzył
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Jeśli uderzyliśmy w RigidBody2D (nasz przedmiot)
		if collider is RigidBody2D:
			# Uderzamy go (popychamy) w stronę przeciwną do naszego zderzenia
			collider.apply_central_impulse(-collision.get_normal() * push_force)
	
	
	
	# Respawn
	if Input.is_action_just_pressed("RespawnButton") :
		respawn()
		print("Gracz się odrodził!")
		return
	
	# Use item
	if Input.is_action_just_pressed("UseItemButton"):
		var _item = inventory.get_current_item()
		
		if _item is UseableItem and interaction_and_attack_stats_script.can_attack():
			var used_successfully = false 
			
			# === LOGIKA LECZENIA ===
			if _item is HealingItem:
				if _item.affect_target(self):
					inventory.consume_current_item()
					used_successfully = true
			
			# === LOGIKA UŻYCIA BRONI ===
			elif _item is ItemWeapon:
				var hit_someone = false
				
				# 1. NAJPIERW sprawdzamy, czy kogoś namierzamy celownikiem
				if current_gamepad_target != null:
					var potential_enemy = current_gamepad_target.get_parent() # Pobieramy głównego wroga
					if potential_enemy.is_in_group("Enemy"):
						if _item.affect_target(potential_enemy):
							inventory.consume_durability_of_the_item()
							used_successfully = true
							hit_someone = true
				
				# 2. Jeśli nikogo nie namierzaliśmy, sprawdzamy czy awaryjnie w kogoś nie wpadliśmy ciałem
				#if not hit_someone:
					#for i in get_slide_collision_count():
						#var collision = get_slide_collision(i)
						#var collider = collision.get_collider()
					#
						#if collider.is_in_group("Enemy"):
							#if _item.affect_target(collider):
								#inventory.consume_durability_of_the_item()
								#used_successfully = true
								#break 
			
			# Jeśli użyto z sukcesem - reset cooldownu
			if used_successfully:
				interaction_and_attack_stats_script.reset_cooldown()
	
	
	#region Attack test script (WALKA Z PIĘŚCI)
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
	
	if Input.is_action_pressed("Attack") and interaction_and_attack_stats_script.can_attack():
		var hit_someone = false
		
		# 1. Atak z pięści w namierzony cel
		if current_gamepad_target != null:
			var potential_enemy = current_gamepad_target.get_parent()
			if potential_enemy.is_in_group("Enemy"):
				print("Gracz atakuje namierzonego przeciwnika!")
				interaction_and_attack_stats_script.hand_attack(potential_enemy)
				hit_someone = true
				
		# 2. Awaryjny atak w to, czego dotykamy
		if not hit_someone:
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				
				if collider.is_in_group("Enemy"):
					print("Gracz atakuje zderzonego przeciwnika!")
					interaction_and_attack_stats_script.hand_attack(collider)
					break
	#endregion
	
	
	# NOWE: Obsługa celowania padem / strzałkami
	handle_gamepad_aiming()
	
	# NOWE: Użycie namierzonego obiektu
	if Input.is_action_just_pressed("Interact"): # np. przycisk 'A' na padzie lub 'E' na klawiaturze
		if current_gamepad_target != null:
			current_gamepad_target.interact(self)

func _input(event: InputEvent) -> void:
	# 1. Wykrycie myszki (ruch lub kliknięcie)
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		is_using_mouse = true
		
	# 2. Wykrycie pada (ruch gałką powyżej martwej strefy lub wciśnięcie przycisku)
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.2:
		is_using_mouse = false
	elif event is InputEventJoypadButton:
		is_using_mouse = false
		
	# 3. Wykrycie klawiatury (jeśli strzałki "Aim..." używają klawiszy)
	elif event is InputEventKey and event.is_pressed():
		if event.is_action("AimLeft") or event.is_action("AimRight") or event.is_action("AimUp") or event.is_action("AimDown"):
			is_using_mouse = false


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
	else:
		# Jeśli to zwykły ItemData bez cooldownu, wracamy do limitu z pustych rąk
		interaction_and_attack_stats_script.actual_cooldown = interaction_and_attack_stats_script.hand_cooldown

func _on_inventory_item_dropped(dropped_item_data: ItemData):
	if item_pickup_scene == null:
		print("Błąd: Brak przypisanej sceny item_pickup_scene w Graczu!")
		return
	
	var drop = item_pickup_scene.instantiate()
	drop.item_data = dropped_item_data
	
	
	# --- Fizyczne wyrzucenie przedmiotu ---
	
	# Dodajemy obiekt do głównego węzła mapy
	get_tree().current_scene.add_child(drop)
	
	# Ustawiamy punkt startowy na środek gracza
	drop.global_position = global_position
	
	# Ustawiamy kierunek (wektor), w którym poleci przedmiot
	# 1. Pobieramy bazowy kierunek z celownika (RayCast2D zawsze jest zwrócony tam, gdzie celujemy)
	var aim_direction = aim_scanner.target_position.normalized()
	
	# Zabezpieczenie: gdyby z jakiegoś powodu wektor wynosił (0,0), rzucamy w dół
	if aim_direction == Vector2.ZERO:
		# Losujemy kierunek (wektor), w którym poleci przedmiot
		aim_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	
	# 2. Dodajemy delikatny rozrzut (spread), żeby przedmioty nie spadały idealnie w ten sam piksel
	var spread = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	var drop_direction = (aim_direction + spread).normalized()
	
	# Siła wyrzutu (możesz ją zwiększyć, jeśli przedmioty mają lecieć dalej)
	var drop_force = randf_range(200.0, 300.0)
	
	# Ponieważ nasz upuszczany przedmiot to RigidBody2D, traktujemy go fizycznie
	if drop is RigidBody2D:
		drop.apply_central_impulse(drop_direction * drop_force)

func _on_item_broken(broken_item_name: String):
	print("Twój przedmiot zniszczył się: ", broken_item_name)
	# Tutaj możesz dodać np.: $AudioStreamPlayer.play()


func handle_gamepad_aiming():
	if is_using_mouse:
		# TRYB MYSZKI: Celownik na bieżąco śledzi kursor
		var local_mouse_pos = get_local_mouse_position()
		aim_scanner.target_position = local_mouse_pos.limit_length(aim_distance)
	else:
		# TRYB PADA/STRZAŁEK: Sprawdzamy wychylenie
		var aim_vector = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
		
		if aim_vector != Vector2.ZERO:
			# Jeśli wychylamy, aktualizujemy pozycję celownika
			aim_scanner.target_position = aim_vector.normalized() * aim_distance
		# Jeśli aim_vector == Vector2.ZERO (gałka puszczona), nic NIE ROBIMY.
		# Dzięki temu RayCast2D zostaje zamrożony w miejscu, w którym ostatnio celowaliśmy!
		
	# Wymuszamy fizykę lasera
	aim_scanner.force_raycast_update()
	
	var collider = aim_scanner.get_collider()
	var found_target: InteractableComponent = null
	
	# Szukamy naszego komponentu (bezpośrednio lub w głównym ciele wroga)
	if collider != null:
		if collider is InteractableComponent:
			found_target = collider
		else:
			for child in collider.get_children():
				if child is InteractableComponent:
					found_target = child
					break
	
	# Zarządzanie podświetlaniem celu
	if found_target != null:
		if current_gamepad_target != found_target:
			if current_gamepad_target != null:
				current_gamepad_target.untarget()
			
			current_gamepad_target = found_target
			current_gamepad_target.target()
	else:
		clear_gamepad_target()

func clear_gamepad_target():
	if current_gamepad_target != null:
		current_gamepad_target.untarget()
		current_gamepad_target = null
