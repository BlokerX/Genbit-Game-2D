## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

#region Podłączone komponenty indywidualne dla gracza

## Komponent ekwipunku gracza
@export var inventory : Inventory

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory

#endregion

#region Obsługa przedmiotów w inventory

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

@export var item_pickup_scene: PackedScene = preload("res://assets/scenes/item_pickup.tscn")

var drop_hold_time: float = 0.0
## Czas w sekundach wymagany do wyrzucenia całego stacka
var time_required_for_full_stack: float = 0.5 

#endregion

#region Pociski

## Scena pocisku dla broni dystansowej
@export var projectile_scene: PackedScene 
## Mnożnik siły wyrzucania przedmiotów
@export var throw_force_multiplier: float = 3.0 
## Siła z jaką gracz popycha obiekty fizyczne
@export var push_force: float = 10.0 
#endregion

#region Skaner / Celownik

## Skaner celownika
@onready var aim_scanner: RayCast2D = $AimScanner

## Zasięg celownika (tylko interakcje nieposiadające ograniczonego dystansu)
@export var aim_distance: float = 4000.0

# --------
# TARGETY:
# --------

## Przechowujemy aktualnie namierzony obiekt przez celownik
var current_target: InteractableComponent = null

## Pamięta ostatni cel, który zgubiliśmy tylko przez to, że wybiegliśmy z zasięgu
var last_target: InteractableComponent = null

# -----------
# KONTROLERY:
# -----------

# Pamięta, z jakiego kontrolera gracz ostatnio korzystał
var is_using_mouse: bool = true

# Pamięta, czy gracz trzyma przycisk ataku, żeby atakować seriami (ciągły atak)
var is_holding_attack: bool = false

# ----------------
# OPCJE CELOWNIKA:
# ----------------

## Czy system ma automatycznie zrzucać focus z przedmiotów na wrogów (Pad/Klawiatura)?
@export var auto_enemy_selector: bool = true

## Czy system ma automatycznie namierzać najbliższego wroga i pamiętać ostatniego? (Priorytet dla walki na padzie/klawiaturze)
@export var auto_lock_closest_enemy: bool = true

## Czy celownik ma być aktywny cały czas (True), czy tylko podczas wychylania gałki/strzałek (False)? 
@export var continuous_gamepad_aiming: bool = false

## Czy myszka ma trzymać cel dopóki z niego nie odejdziemy (True), czy odznaczać go od razu po zjechaniu kursorem w pustą przestrzeń (False)?
@export var sticky_mouse_aiming: bool = false

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
	interaction_and_attack_stats_script.hand_attack_data.cooldown = 1.0
	
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
	
	# Obsługa celowania skanerem
	handle_aiming()
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
		auto_enemy_selector = !auto_enemy_selector
		auto_lock_closest_enemy = !auto_lock_closest_enemy
		
		# Opcjonalnie: Wyświetlamy informację w konsoli (później możesz to podpiąć pod jakiś napis na ekranie/UI)
		if auto_enemy_selector:
			print("Auto-Enemy Selector With Locking Closest Enemy: WŁĄCZONY")
		else:
			print("Auto-Enemy Selector With Locking Closest Enemy: WYŁĄCZONY")
			
			# Jeśli wyłączyliśmy tryb, a celownik trzymał wroga "na siłę", warto zresetować celownik:
			clear_gamepad_target()
	
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
		if current_target != null:
			current_target.interact(self)
	
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
		interaction_and_attack_stats_script.actual_cooldown = interaction_and_attack_stats_script.hand_attack_data.cooldown
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
		var aim_direction = aim_scanner.target_position.normalized()
		
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

#region System celowania

# ==========================================
# GŁÓWNY SYSTEM CELOWANIA
# ==========================================

## Główna obsługa celowania
func handle_aiming():
	if is_using_mouse:
		handle_mouse_aiming()
	else:
		handle_gamepad_aiming()

## --- CELOWANIE MYSZKĄ ---
func handle_mouse_aiming():
	# 1. Ustawienie pozycji lasera za myszką
	var local_mouse_pos = get_local_mouse_position()
	aim_scanner.target_position = local_mouse_pos.limit_length(aim_distance)
	
	# 2. Aktualizacja Raycastu
	aim_scanner.force_raycast_update()
	var found_target = _get_raycast_target()
	
	# 3. Zabezpieczenie fizyczne dystansu
	found_target = _enforce_distance_check(found_target)
	
	# 4. Zarządzanie podświetlaniem celu (dla myszki is_gamepad = false)
	_manage_target_highlight(found_target, false)

## --- CELOWANIE PADEM / KLAWIATURĄ ---
func handle_gamepad_aiming():
	var final_aim_dir = Vector2.ZERO
	var is_pad_aiming = false 
	
	# 1. Odczyt wychylenia gałki/strzałek
	var aim_vector = Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	if aim_vector != Vector2.ZERO:
		is_pad_aiming = true
		var raw_aim_dir = aim_vector.normalized()
		final_aim_dir = raw_aim_dir
		
		# Magnetyzm celownika
		if current_target != null and is_instance_valid(current_target):
			var target_parent = current_target.get_parent()
			if target_parent != null:
				var dir_to_target = global_position.direction_to(target_parent.global_position)
				if abs(raw_aim_dir.angle_to(dir_to_target)) < 0.8: 
					final_aim_dir = dir_to_target
		
		aim_scanner.target_position = final_aim_dir * aim_distance
	else:
		if not continuous_gamepad_aiming:
			aim_scanner.target_position = Vector2.ZERO
			
	# 2. Aktualizacja Raycastu
	aim_scanner.force_raycast_update()
	var found_target = _get_raycast_target()
	var found_is_enemy = false
	
	if found_target != null:
		var tp = found_target.get_parent()
		if tp and tp.is_in_group("Enemy"):
			found_is_enemy = true

	# --- NOWY SYSTEM PAMIĘCI I AUTO-CELOWANIA WROGÓW ---
	if auto_lock_closest_enemy and not found_is_enemy:
		var best_enemy = null
		var best_dist = get_current_attack_range()
		
		# KROK 1: Sprawdźmy, czy gałka jest aktywnie wychylana. Jeśli tak, priorytet ma cel w kierunku wychylenia.
		if is_pad_aiming:
			var best_angle = 0.6 
			for enemy in get_tree().get_nodes_in_group("Enemy"):
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= best_dist and _has_line_of_sight(enemy):
					var dir_to_enemy = global_position.direction_to(enemy.global_position)
					var angle = abs(final_aim_dir.angle_to(dir_to_enemy))
					if angle < best_angle:
						best_angle = angle
						best_enemy = enemy
		
		# KROK 2: Jeśli nie używamy gałki (albo nikt nie stał na drodze promienia z KROKU 1), skanujemy otoczenie!
		if best_enemy == null and not is_pad_aiming:
			# a) Sprawdzamy "pamięć" (czyli last_target - wroga z którym walczyliśmy, ale uciekł na chwilę z zasięgu)
			if last_target != null and is_instance_valid(last_target):
				var lp = last_target.get_parent()
				if lp and lp.is_in_group("Enemy"):
					var dist = global_position.distance_to(lp.global_position)
					if dist <= best_dist and _has_line_of_sight(lp):
						best_enemy = lp
						best_dist = dist # Ustawiamy jego dystans jako punkt odniesienia
			
			# b) Skanujemy wszystkich wrogów. Jeśli znajdziemy jakiegoś wroga BLIŻEJ niż zapamiętany (lub jeśli pamięć jest pusta), obieramy nowy cel
			for enemy in get_tree().get_nodes_in_group("Enemy"):
				var dist = global_position.distance_to(enemy.global_position)
				# Zwróć uwagę na znak mniejszości (<). Nowy wróg musi być wyraźnie bliżej, aby nadpisać pamięć starego celu.
				if dist < best_dist and _has_line_of_sight(enemy):
					best_dist = dist
					best_enemy = enemy
					
		# Aplikowanie wybranego wroga do zmiennych
		if best_enemy != null:
			for child in best_enemy.get_children():
				if child is InteractableComponent:
					found_target = child
					found_is_enemy = true
					break

	# --- FALLBACK dla starszego ustawienia (opcjonalny, jeśli wyłączysz nową flagę) ---
	elif is_pad_aiming and auto_enemy_selector and not found_is_enemy and not auto_lock_closest_enemy:
		var best_enemy = null
		var best_angle = 0.6 
		for enemy in get_tree().get_nodes_in_group("Enemy"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= get_current_attack_range(): 
				var dir_to_enemy = global_position.direction_to(enemy.global_position)
				var angle = abs(final_aim_dir.angle_to(dir_to_enemy))
				if angle < best_angle:
					best_angle = angle
					best_enemy = enemy
		if best_enemy != null:
			for child in best_enemy.get_children():
				if child is InteractableComponent:
					found_target = child
					found_is_enemy = true
					break

	# --- ZAMROŻENIE CELU (Hard Sticky Target) ---
	# Podtrzymujemy fokus tak długo, jak cel żyje, jest w zasięgu i nie jest zasłonięty ścianą.
	if (continuous_gamepad_aiming or auto_lock_closest_enemy) and not is_pad_aiming and current_target != null and is_instance_valid(current_target):
		var is_current_reachable = false
		var target_parent = current_target.get_parent()
		var current_is_enemy = target_parent and target_parent.is_in_group("Enemy")
		
		if current_is_enemy:
			if global_position.distance_to(target_parent.global_position) <= get_current_attack_range() and _has_line_of_sight(target_parent):
				is_current_reachable = true
		else:
			if global_position.distance_to(current_target.global_position) <= aim_distance:
				is_current_reachable = true
				
		var allow_sticky = true
		# Odepnij obecny podniesiony cel (np. przedmiot), jeśli mamy wroga na radarze i włączony priorytet
		if auto_enemy_selector and not current_is_enemy and found_is_enemy:
			allow_sticky = false 
			
		if is_current_reachable and allow_sticky:
			found_target = current_target
			found_is_enemy = current_is_enemy

	# 3. Zabezpieczenie fizyczne dystansu
	found_target = _enforce_distance_check(found_target)

	# 4. Zarządzanie podświetlaniem (i uzupełnianie last_target gdy cel się oddala!)
	_manage_target_highlight(found_target, true, is_pad_aiming)

## Oczyszcza aktualny cel i usuwa obrysowanie
func clear_gamepad_target():
	if current_target != null:
		current_target.untarget()
		current_target = null

# ==========================================
# FUNKCJE POMOCNICZE (Współdzielone)
# ==========================================

## Pobiera InteractableComponent z promienia lasera
func _get_raycast_target() -> InteractableComponent:
	var collider = aim_scanner.get_collider()
	if collider != null:
		if collider is InteractableComponent:
			return collider
		else:
			for child in collider.get_children():
				if child is InteractableComponent:
					return child
	return null

## Sprawdza i limituje obiekt pod kątem dystansu z zasięgiem broni
func _enforce_distance_check(target: InteractableComponent) -> InteractableComponent:
	if target != null:
		var is_reachable = false
		var target_parent = target.get_parent()
		
		if target_parent and target_parent.is_in_group("Enemy"):
			var dist_to_enemy = global_position.distance_to(target_parent.global_position)
			if dist_to_enemy <= get_current_attack_range():
				is_reachable = true
		else:
			var dist_to_object = global_position.distance_to(target.global_position)
			if dist_to_object <= aim_distance:
				is_reachable = true
				
		if not is_reachable:
			return null
	return target

# Sprawdza, czy gracz ma czystą linię strzału/ciosu do celu (nie zasłaniają go ściany)
func _has_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	
	# Wykluczamy samego gracza z kolizji promienia
	query.exclude = [self.get_rid()]
	
	# Ważne: Jeśli twoje ściany mają specyficzną warstwę fizyki (Collision Layer), odkomentuj poniższą linię.
	# Domyślnie sprawdza wszystkie warstwy, co może zablokować atak na innej jednostce / przedmiocie.
	query.collision_mask = 1 # Ustaw maskę kolizji odpowiednią dla przeszkód (ścian)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		# Jeśli promień trafił we wroga, jego Hitbox (dziecko wroga) lub wróg jest dzieckiem trafionego obiektu
		if collider == target or target.is_ancestor_of(collider) or collider.is_ancestor_of(target):
			return true
		# W przeciwnym wypadku promień trafił w coś innego (np. w ścianę TileMap)
		return false
		
	# Jeśli promień w ogóle nic w nic nie uderzył, droga jest wolna (może się zdarzyć, gdy np. wróg nie ma włączonej kolizji)
	return true

## Odpowiada za podświetlanie, odznaczanie i zapisywanie "ostatniego" celu
func _manage_target_highlight(found_target: InteractableComponent, is_gamepad: bool, is_pad_aiming: bool = false):
	if found_target != null:
		if current_target != found_target:
			clear_gamepad_target()
			current_target = found_target
			current_target.target()
			last_target = null
	else:
		if current_target != null:
			var should_drop = false
			var dropped_due_to_distance = false
			
			# --- LOGIKA GUBIENIA CELU ---
			if is_gamepad:
				# Odznacz jeśli celujemy padem, a laser zgubił obiekt
				if is_pad_aiming:
					should_drop = true
			else:
				# Myszka! Jeśli flaga 'sticky' jest wyłączona, odznaczamy natychmiast po zjechaniu kursorem
				if not sticky_mouse_aiming:
					should_drop = true
			
			if not should_drop and is_instance_valid(current_target):
				var is_still_reachable = false
				var target_parent = current_target.get_parent()
				
				if target_parent and target_parent.is_in_group("Enemy"):
					var dist = global_position.distance_to(target_parent.global_position)
					if dist <= get_current_attack_range():
						is_still_reachable = true
				else:
					var dist = global_position.distance_to(current_target.global_position)
					if dist <= aim_distance:
						is_still_reachable = true
						
				if not is_still_reachable:
					should_drop = true
					dropped_due_to_distance = true 
			
			elif not is_instance_valid(current_target):
				should_drop = true
				
			if should_drop:
				if dropped_due_to_distance:
					last_target = current_target
				clear_gamepad_target()

# --- FUNKCJA WALKI Z DYSTANSEM ---
func perform_attack() -> void:
	var _item = inventory.get_current_item()
	var target_enemy = _get_enemy_target()
	
	if target_enemy != null:
		
		# Pobieramy dystans z naszej nowej funkcji
		var max_attack_distance = get_current_attack_range()
		if max_attack_distance <= 0.0:
			return # Mamy w ręku np. miksturę, więc nie atakujemy
			
		# --- Mierzenie dystansu do wroga ---
		var distance_to_enemy = global_position.distance_to(target_enemy.global_position)
		
		# --- Właściwy atak ---
		if distance_to_enemy <= max_attack_distance:
			
			# Sprawdzamy, czy ściana nie blokuje ataku
			if not _has_line_of_sight(target_enemy):
				print("Atak zablokowany przez ścianę!")
				return
				
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
						
						get_tree().current_scene.add_child(new_projectile)
					else:
						print("BŁĄD: Gracz próbuje strzelać, ale nie przypisano 'projectile_scene'!")
				else:
					print("Cios z broni białej!")
					interaction_and_attack_stats_script.execute_attack_on_target(target_enemy)
					# Zużywamy wytrzymałość broni po ataku
					inventory.consume_durability_of_the_item()
				
			elif _item == null:
				print("Gracz trafia z pięści!")
				interaction_and_attack_stats_script.execute_attack_on_target(target_enemy)
		else:
			print("Pudło! Wróg poza zasięgiem broni. (Dystans: ", distance_to_enemy, " / Max: ", max_attack_distance, ")")

# Zwraca aktualny zasięg ataku w zależności od przedmiotu
func get_current_attack_range() -> float:
	var _item = inventory.get_current_item()
	if _item is ItemWeapon:
		# Broń posiada mnożnik zasięgu (np. 1.0, 1.5) względem bazowego celownika (aim_distance)
		return aim_distance * _item.attack_data.max_range
	elif _item == null:
		# Puste ręce (pięści) posiadają swój własny zasięg w pikselach (np. 50), nie mnożymy tego!
		return float(interaction_and_attack_stats_script.get_total_range())
	else:
		return 0.0 # Przedmioty konsumpcyjne nie mają zasięgu ataku

## Zwraca namierzonego wroga lub tego, z którym się zderzamy. Zwraca null, jeśli brak wroga.
func _get_enemy_target() -> Node2D:
	# 1. Sprawdzamy celownik (RayCast/Myszka)
	if current_target != null:
		var potential_enemy = current_target.get_parent()
		if potential_enemy.is_in_group("Enemy"):
			return potential_enemy
			
	# 2. Awaryjnie sprawdzamy zderzenia ciała (jeśli laser nikogo nie widzi)
	#for i in get_slide_collision_count():
		#var collision = get_slide_collision(i)
		#var collider = collision.get_collider()
		#if collider != null and collider.is_in_group("Enemy"):
			#return collider
			
	return null

#endregion
