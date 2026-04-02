## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity

class_name PlayerCharacter

@export var inventory : Inventory
@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")



@onready var aim_scanner: RayCast2D = $AimScanner

# Przechowujemy aktualnie namierzony obiekt przez pada
var current_gamepad_target: InteractableComponent = null

# Zasięg naszego celownika
@export var aim_distance: float = 200.0



func _ready():
	movement_universal_script = preload("res://assets/scripts/entities/movement/special_instations/player_movement_component.tres")
	# moveSpeed = 450
	# accelerationMultiplayer = 5.0
	# decelerationMultiplayer = 0.825
	
	health_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_monitored_life_stats_component.tres")
	
	interaction_and_attack_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_interaction_and_attack_stats_component.tres")
	interaction_and_attack_stats_script.hand_damage = 10
	interaction_and_attack_stats_script.hand_cooldown = 1.0
	
	# Health points bar initialization
	super()
	
	inventory.inventory_updated.connect(on_inventory_update)
	on_inventory_update()
	
	inventory.item_dropped.connect(_on_inventory_item_dropped)

func on_inventory_update() :
	
	#region debug log
	
	print("================")
	print("Inventory state:")
	print("---")
	var __item_name : String = "null"
	var __item_durable : String = "null"
	var __item_max_durable : String = "null"
	var __item_stack_count : String = "null"
	var __item_max_stack_count : String = "null"
	var __item_is_stackable : String = "null"
	if inventory.get_current_item() != null :
		__item_name = inventory.get_current_item().item_name
		__item_durable = str(inventory.get_current_item().durable)
		__item_max_durable = str(inventory.get_current_item().max_durable)
		__item_stack_count = str(inventory.get_current_item().item_stack_count)
		__item_max_stack_count = str(inventory.get_current_item().item_max_stack_count)
		__item_is_stackable = str(inventory.get_current_item().item_is_stackable)
	print("Current item (slot number = " + str(inventory.current_item_index + 1) + " / " + str(inventory.max_items) + "): " + __item_name)
	print("Durability of the item = " + __item_durable + " / " + __item_max_durable)
	print("Is item stackable = " + __item_is_stackable)
	print("Stack of the item = " + __item_stack_count + " / " + __item_max_stack_count)
	print("---")
	print("Items:")
	for item in inventory.items :
		if item != null :
			print(item.item_name)
	print("================")
	
	#endregion
	
	# Aktualizacja cooldown po zmianie itemu
	# Po podniesieniu lub zmianie przedmiotu aktualizujemy limit cooldownu postaci
	var current_item = inventory.get_current_item()
	
	
	if current_item != null:
		# Jeśli slot nie jest pusty, wkładamy przedmiot do dłoni rycerza.
		# UWAGA: Twoja zmienna w ItemData nazywa się 'item_icon'.
		held_item_visual.texture = current_item.item_icon
		held_item_visual.show() # Pokazujemy dłoń
	else:
		# Jeśli slot jest pusty, czyścimy dłoń
		held_item_visual.texture = null
		held_item_visual.hide() # Ukrywamy, żeby nie było widać "niczego"
	
	
	# Podłączamy sygnał do aktywnego przedmiotu, jeśli to broń
	if current_item != null and not current_item.item_broken.is_connected(_on_item_broken):
		current_item.item_broken.connect(_on_item_broken)
	
	
	
	# Teraz sprawdzamy czy to jakikolwiek UseableItem (a nie tylko ItemWeapon)
	if current_item is UseableItem:
		# Przekazujemy cooldown przedmiotu do statystyk gracza
		interaction_and_attack_stats_script.actual_cooldown = current_item.use_cooldown
	else:
		# Jeśli to zwykły ItemData bez cooldownu, wracamy do limitu z pustych rąk
		interaction_and_attack_stats_script.actual_cooldown = interaction_and_attack_stats_script.hand_cooldown

func _on_inventory_item_dropped(dropped_item_data: ItemData):
	var drop = item_pickup_scene.instantiate()
	drop.item_data = dropped_item_data
	
	# Lepiej dodać do konkretnego węzła na przedmioty na mapie (np. "ItemsDropContainer") 
	# niż zaśmiecać korzeń mapy, ale get_tree().current_scene na razie wystarczy
	get_tree().current_scene.add_child(drop)
	
	var random_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	drop.global_position = global_position + random_offset

func _on_item_broken(broken_item_name: String):
	print("Twoja broń zniszczyła się: ", broken_item_name)
	# Tutaj możesz dodać np.: $AudioStreamPlayer.play()

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
	
	
	
	# NOWE: System popychania fizycznych przedmiotów!
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

func handle_gamepad_aiming():
	# 1. Sprawdzamy wychylenie prawej gałki na padzie
	var aim_vector = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	
	if aim_vector != Vector2.ZERO:
		# Jeśli używamy PADA, laser strzela w kierunku gałki
		aim_scanner.target_position = aim_vector.normalized() * aim_distance
	else:
		# 2. Jeśli nie używamy pada, laser ZAWSZE ŚLEDZI MYSZKĘ
		var local_mouse_pos = get_local_mouse_position()
		# Ustawiamy laser na myszkę, ale ograniczamy jego maksymalną długość
		aim_scanner.target_position = local_mouse_pos.limit_length(aim_distance)
		
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

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory
