extends ItemWeapon
class_name ItemDistanceWeapon

@export_category("Distance Weapon Settings")

@export_group("Ustawienia Amunicji")
## Czy ta broń w ogóle potrzebuje amunicji? (False dla lasera lub rzucanego kamienia)
@export var uses_ammunition: bool = true

## Jaki typ amunicji przyjmuje ta broń? (Musi pasować do 'ammunition_type' w AmmunitionItem)
@export var accepted_ammunition_type: String

## Pojemność magazynka. (1 dla łuku/kuszy, 30 dla karabinu)
@export var magazine_capacity: int = 1

## Czy broń ma się przeładować sama, gdy gracz wciśnie strzał na pustym magazynku?
@export var auto_reload: bool = true

## Czas potrzebny na przeładowanie magazynka (w sekundach)
@export var reload_time: float = 2.5

@export_group("Pocisk")

## Tekstura pocisku wystrzeliwanego przez tę konkretną broń
@export var projectile_texture : Texture2D

## Prędkość z jaką porusza się pocisk
@export var projectile_speed : float = 500.0

## Czas życia pocisku w sekundach (zanim sam zniknie, jeśli w nic nie trafi)
@export var projectile_lifetime : float = 2.0

## UWAGA: Każda broń dystansowa powinna mieć własną scenę pocisku przypisaną tutaj!
@export var projectile_scene: PackedScene

## Constructor
# Constructor
func _init(
	# --- Argumenty z UseableItem i ItemData ---
	_item_id : int = 1,
	_item_name : String = "Distance Weapon",
	_item_type : String = "Weapon",
	_item_description : String = "",
	_item_is_stackable : bool = false,
	_item_max_stack_count : int = 1,
	_item_sprite : Texture2D = null,
	_max_durable : int = -1,
	_use_cooldown : float = 1.0,
	_effects : Array[Effect] = [],
	# --- Argumenty z ItemWeapon ---
	_attack_data : AttackData = AttackData.new(1, 0, 0.0, 1.0, 0.0),
	_weapon_type : String = "Bow",
	# --- Nowe argumenty dla ItemDistanceWeapon ---
	_projectile_texture : Texture2D = null,
	_projectile_speed : float = 500.0,
	_projectile_lifetime : float = 2.0
) :
	
	# 1. Wywołanie konstruktora _init() z klasy ItemWeapon.
	# Zwróć uwagę na przedostatni argument: przekazujemy 'true', 
	# aby wymusić is_ranged = true w klasie bazowej.
	super(
		_item_id, 
		_item_name, 
		_item_type, 
		_item_description, 
		_item_is_stackable, 
		_item_max_stack_count,
		_item_sprite, 
		_max_durable, 
		_use_cooldown, 
		_effects, 
		_attack_data, 
		true, # Zawsze true dla broni dystansowej
		_weapon_type
	)
	
	# 2. Inicjalizacja dla aktualnej klasy (ItemDistanceWeapon)
	projectile_texture = _projectile_texture
	projectile_speed = _projectile_speed
	projectile_lifetime = _projectile_lifetime

# --- NADPISANIE FUNKCJI ATAKU DLA BRONI DYSTANSOWEJ ---
func execute_attack(shooter: CharacterEntity, target: Node2D, weapon_instance: ItemInstance, inventory: Inventory, stats_script: InteractionAndAttackStatsComponent, spawner: Node) -> bool:
	
	if projectile_scene == null:
		push_error("BŁĄD: Broń " + item_name + " nie ma przypisanej sceny pocisku!")
		return false
		
	# ========================================================
	# 1. INTELIGENTNY SYSTEM AMUNICJI (Weryfikacja przed strzałem)
	# ========================================================
	var ammo_data: AmmunitionItem = null
	
	if uses_ammunition:
		var current_ammo = weapon_instance.custom_data.get("ammo_count", 0)
		
		# PRÓBA STRZAŁU NA PUSTYM MAGAZYNKU
		if current_ammo <= 0:
			if not auto_reload:
				print("Klik! Magazynek pusty. Wymagane ręczne przeładowanie.")
				return false # Odmawiamy strzału
				
			if inventory.reload_current_weapon():
				print("Auto-przeładowanie: " + item_name)
				# Nakładamy karę czasową za przeładowanie!
				stats_script.trigger_reload_cooldown(reload_time)
			else:
				print("Klik! Brak amunicji w plecaku dla: " + item_name)
				
			# Przerywamy ten konkretny strzał - gracz musi poczekać aż minie cooldown przeładowania!
			return false 
			
		# Mamy amunicję - przygotowujemy się do strzału
		ammo_data = weapon_instance.custom_data.get("ammo_data", null)
		weapon_instance.custom_data["ammo_count"] = current_ammo - 1

	# ========================================================
	# 2. OBLICZANIE OBRAŻEŃ (Laser vs Magazynek)
	# ========================================================
	var base_damage = 0
	
	if uses_ammunition:
		base_damage = ammo_data.damage if ammo_data != null else 0
	else:
		base_damage = stats_script.actual_attack_data.damage

	var final_damage = int((base_damage + stats_script.damage_adder) * stats_script.damage_multiplier)
	
	var crit_rate = stats_script.get_total_critical_rate()
	var crit_dmg = stats_script.get_total_critical_damage()
	if randf() <= crit_rate:
		final_damage += int(crit_dmg)
		print("KRYTYK dystansowy! Obrażenia: ", final_damage)

	# ========================================================
	# 3. GENEROWANIE PAKIETU EFEKTÓW
	# ========================================================
	var generated_effects: Array[Effect] = []
	
	generated_effects.append(DamageEffect.new(final_damage))
	
	var final_stun = stats_script.get_total_stun()
	if final_stun > 0.0:
		generated_effects.append(StunEffect.new(final_stun))
		
	if stats_script.actual_extra_effects != null:
		for effect in stats_script.actual_extra_effects:
			if effect != null: generated_effects.append(effect.duplicate(true))

	# ========================================================
	# 4. FUZJA BALISTYCZNA Z AMUNICJĄ
	# ========================================================
	var final_speed = projectile_speed
	var final_texture = projectile_texture
	
	if ammo_data != null:
		final_speed *= ammo_data.speed_multiplier
		
		if ammo_data.override_projectile_texture != null:
			final_texture = ammo_data.override_projectile_texture
			
		if ammo_data.effects != null:
			for effect in ammo_data.effects:
				if effect != null: generated_effects.append(effect.duplicate(true))

	# ========================================================
	# 5. SPAWN POCISKU
	# ========================================================
	var new_projectile = projectile_scene.instantiate()
	new_projectile.shooter = shooter
	new_projectile.global_position = shooter.global_position
	
	var shoot_dir = shooter.global_position.direction_to(target.global_position)
	new_projectile.direction = shoot_dir
	new_projectile.rotation = shoot_dir.angle() + (PI / 2.0) 
	
	if "effects_to_apply" in new_projectile: new_projectile.effects_to_apply = generated_effects
	if "speed" in new_projectile: new_projectile.speed = final_speed
	elif "projectile_speed" in new_projectile: new_projectile.projectile_speed = final_speed
	if "lifetime" in new_projectile: new_projectile.lifetime = projectile_lifetime
	
	var sprite = new_projectile.get_node_or_null("Sprite2D")
	if sprite != null and final_texture != null: sprite.texture = final_texture
		
	spawner.spawn_projectile_requested.emit(new_projectile, shooter.global_position)
	
	# ========================================================
	# 6. ZUŻYCIE BRONI I ZEGAR (COOLDOWN)
	# ========================================================
	weapon_instance.reduce_durability()
	
	# Sprawdzamy czy po strzale magazynek jest pusty, aby zrobić płynny auto-reload w tle (Dla Łuków/Kusz)
	if uses_ammunition and auto_reload and weapon_instance.custom_data["ammo_count"] <= 0:
		if inventory.reload_current_weapon():
			print("Magazynek pusty - auto-przeładowanie po strzale!")
			stats_script.trigger_reload_cooldown(reload_time)
			return true # Zwracamy true, bo strzał padł, ale stoper ataku to teraz długi czas przeładowania!
	
	# Jeśli nie było auto-przeładowania, resetujemy normalny, szybki cooldown dla kolejnego strzału
	stats_script.reset_cooldown() 
	
	return true
