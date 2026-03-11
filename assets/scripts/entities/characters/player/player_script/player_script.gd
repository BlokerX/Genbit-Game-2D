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
	
	attack_stats_script = preload("res://assets/scripts/entities/stats/special_instations/player_attack_stats_component.tres")
	attack_stats_script.attack_damage = 10
	attack_stats_script.attack_cooldown = 1.0
	
	respawnVector = Vector2(512, 360)
	
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

func _process(delta):
	# Update health gui data.
	super(delta)
	
	#region Test Inventory
	
	# Pobieramy aktualny przedmiot z ekwipunku
	var current_item = inventory.get_current_item()
	
	# Jeśli to jest UseableItem, odświeżamy jego cooldown
	if current_item is UseableItem :
		current_item.cooldown_process(delta)
		
	#endregion

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
		
		if _item is UseableItem:
			
			# === LOGIKA LECZENIA / KONSUMPCJI ===
			if _item is HealingItem:
				# Nakładamy efekty (np. HealEffect, FullRestoreEffect) na samego gracza
				if _item.affect_target(self):
					inventory.consume_current_item()
					
			# === LOGIKA UŻYCIA BRONI ===
			elif _item is ItemWeapon:
				# Sprawdzamy kolizje w poszukiwaniu przeciwnika
				for i in get_slide_collision_count():
					var collision = get_slide_collision(i)
					var collider = collision.get_collider()
					
					if collider.is_in_group("Enemy") and _item.is_ready_to_use():
						# Nakładamy efekty broni (np. DamageEffect, StunEffect) na przeciwnika
						if _item.affect_target(collider):
							inventory.consume_durability_of_the_item()
							# Zatrzymujemy pętlę, by jedno użycie broni nie uderzyło wielu wrogów naraz 
							# (chyba że zależy Ci na obrażeniach obszarowych - wtedy usuń 'break')
							break
	
	
	#region Attack test script:
	attack_stats_script.attack_cooldown_process(delta)
	
	# Sprawdzanie wszystkich kolizji w danej klatce
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if Input.is_action_pressed("Attack") and collider.is_in_group("Enemy") and attack_stats_script.can_attack():
			print("Gracz atakuje przeciwnika!")
			attack_stats_script.attack(collider)
	#endregion
