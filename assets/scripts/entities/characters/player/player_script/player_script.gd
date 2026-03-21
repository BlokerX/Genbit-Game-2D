## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity

class_name PlayerCharacter

@export var inventory : Inventory

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

func on_inventory_update() :
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
	
	# Aktualizacja cooldown po zmianie itemu
	# Po podniesieniu lub zmianie przedmiotu aktualizujemy limit cooldownu postaci
	var current_item = inventory.get_current_item()
	
	
	
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
	
	# Respawn
	if Input.is_action_just_pressed("RespawnButton") :
		respawn()
		print("Gracz się odrodził!")
		return
	
	# Use item
	if Input.is_action_just_pressed("UseItemButton"):
		var _item = inventory.get_current_item()
		
		# Sprawdzamy czy to przedmiot używalny I CZY postać może go użyć (globalny cooldown)
		if _item is UseableItem and interaction_and_attack_stats_script.can_attack():
			
			var used_successfully = false # Zmienna śledząca, czy faktycznie użyliśmy przedmiotu
			
			# === LOGIKA LECZENIA / KONSUMPCJI ===
			if _item is HealingItem:
				# Nakładamy efekty (np. HealEffect, FullRestoreEffect) na samego gracza
				if _item.affect_target(self):
					inventory.consume_current_item()
					used_successfully = true
			
			# === LOGIKA UŻYCIA BRONI ===
			elif _item is ItemWeapon:
				for i in get_slide_collision_count():
					var collision = get_slide_collision(i)
					var collider = collision.get_collider()
				
					if collider.is_in_group("Enemy"):
						# Nakładamy efekty broni (np. DamageEffect, StunEffect) na przeciwnika
						if _item.affect_target(collider):
							inventory.consume_durability_of_the_item()
							used_successfully = true
							break # Uderzyliśmy jednego wroga, przerywamy
			
			# === (Opcjonalnie) Inne typy przedmiotów ===
			# elif _item is MagicScroll:
			#     ...
			
			# Jeśli jakikolwiek przedmiot zadziałał (zaatakowano, wypito potkę), resetujemy globalny czas postaci!
			if used_successfully:
				interaction_and_attack_stats_script.reset_cooldown()
	
	
	#region Attack test script:
	interaction_and_attack_stats_script.interaction_cooldown_process(delta)
	
	# Sprawdzanie wszystkich kolizji w danej klatce
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if Input.is_action_pressed("Attack") and collider.is_in_group("Enemy") and interaction_and_attack_stats_script.can_attack():
			print("Gracz atakuje przeciwnika!")
			interaction_and_attack_stats_script.hand_attack(collider)
	#endregion
