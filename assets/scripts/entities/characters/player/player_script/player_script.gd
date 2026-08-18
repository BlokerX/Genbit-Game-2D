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
const INPUT_RELOAD = "Reload"
const INPUT_USE_ITEM = "UseItemButton"
const INPUT_INTERACT = "Interact"
const INPUT_COLLECT = "Collect"
const INPUT_RESPAWN = "RespawnButton"
const INPUT_TOGGLE_ENEMY_PRIO = "ToggleEnemyPriority"

const INPUT_INV_SLOT_PREFIX = "InventorySlot"
const INPUT_INV_SCROLL_UP = "InventoryScrollUp"
const INPUT_INV_SCROLL_DOWN = "InventoryScrollDown"

## Przycisk obracania obiektów budowlanych (musisz go dodać w Input Map!)
const INPUT_ROTATE = "RotateBuilding"

#endregion

#region Signals

## Sygnał służący do spawnowania obiektów (pociski, wyrzucone przedmioty) bez wiedzy o Map
signal entity_spawn_requested(spawned_node: Node2D, global_spawn_position: Vector2)

# ## Sygnał wykonywany po skończonej inicjalizacji gracza
#signal setup_complete

#endregion

#region Podłączone komponenty indywidualne dla gracza

## Komponent obsługujący wykonywanie ataków
@export var attack_component: AttackComponent

## Komponent ekwipunku gracza
@export var inventory : Inventory

## Komponent odpowiedzialny za wyrzucanie przedmiotów
@export var item_thrower_component: ItemThrowerComponent

## Komponent budowania
@export var builder_component: BuilderComponent

func get_inventory() -> Inventory:
	return inventory # Zwraca wyeksportowaną zmienną inventory

### Aim component
@onready var aim_controller: PlayerAimController = $AimController

#endregion

#region Komponent Celownik / Skaner

# Pamięta, z jakiego kontrolera gracz ostatnio korzystał
var is_using_mouse: bool = true

#endregion

#region Obsługa przedmiotów w inventory

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual

var drop_hold_time: float = 0.0
## Czas w sekundach wymagany do wyrzucenia całego stacka
var time_required_for_full_stack: float = 0.5 

## Przechowuje referencję do ostatnio podłączonego slotu, aby zapobiec wyciekom sygnałów
var last_connected_slot = null

#endregion

#region Atak

# Pamięta, czy gracz trzyma przycisk ataku, żeby atakować seriami (ciągły atak)
var is_holding_attack: bool = false

#endregion

#region Pchnięcie

## Siła z jaką gracz popycha obiekty fizyczne (5.0-ciężki tłum, 10.0-standard, 20.0-taran)
@export var push_force: float = 10.0

#endregion

#region System Stanów Gracza

enum PlayerState { DEFAULT, BUILDING }
var current_state: PlayerState = PlayerState.DEFAULT

# Blokada wejścia z interfejsu UI
var is_input_locked: bool = false

# Blokada pacyfistyczna
var is_in_pacifist_zone: bool = false

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
	
	# Przekazywanie sygnału spawnowania z wyrzucania przedmiotów wyżej
	if item_thrower_component:
		item_thrower_component.entity_spawn_requested.connect(
			func(node, pos): entity_spawn_requested.emit(node, pos)
		)
	
	#region Linkowanie zdarzeń
	if inventory:
		inventory.inventory_updated.connect(on_inventory_update)
		on_inventory_update()
		inventory.item_dropped.connect(_on_inventory_item_dropped)
	#endregion
	
	#setup_complete.emit()
	
	# Nasłuch na zamykanie/otwieranie interfejsu
	EventBus.ui_state_changed.connect(
		func(is_open: bool): is_input_locked = is_open
	)

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)
	
	# --- Tarcza blokująca ruch przy otwartym UI ---
	if is_input_locked:
		velocity = Vector2.ZERO # Błyskawiczny hamulec
		move_and_slide()        # Aplikujemy zatrzymanie
		return                  # Odcinamy funkcję, gracz nic nie robi
	# ------------------------------------------------------
	
	#region Move Procedure
	
	# Movement inputs
	var horizontal := Input.get_axis(INPUT_LEFT, INPUT_RIGHT)
	var vertical := Input.get_axis(INPUT_UP, INPUT_DOWN)
	
	# Movement procedure - bezpieczne wywołanie
	if movement_universal_script != null:
		velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2(horizontal, vertical))
	else:
		velocity = Vector2.ZERO # Jeśli z jakiegoś powodu komponentu nadal nie ma, po prostu stoimy
	
	# Aktualizacja kierunku postaci
	_update_sprite_direction(Vector2(horizontal, vertical))
	
	move_and_slide()
	
	# D_E_B_U_G
	#print("Monitor prędkości gracza: ", velocity)
	
	#endregion
	
	# Obsługa celowania skanerem
	var is_building = (current_state == PlayerState.BUILDING)
	
	# Jeśli budujemy, używamy dystansu z komponentu budowniczego. Jeśli nie - z broni.
	var current_range = builder_component.build_range if is_building else get_current_attack_range()
	
	aim_controller.process_aiming(is_using_mouse, current_range, is_building)
	
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
		
		# 1. Popychanie zwykłych obiektów fizycznych (upuszczony loot, skrzynki fizyczne)
		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * push_force)
			
		# 2. Popychanie Wrogów (np. pająków) - NATURALNE PRZEPYCHANIE
		elif collider is EnemyEntity:
			# Zamiast wstrzykiwać prędkość, wymuszamy gładkie przesunięcie o ułamek piksela.
			# Mnożnik 0.2 przy push_force (10.0) przesuwa wroga o 2 piksele na klatkę.
			# Dzięki użyciu move_and_collide pająk nie przejdzie przez ścianę, jeśli go do niej dociśniesz!
			collider.move_and_collide(-collision.get_normal() * (push_force * 0.2))

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
	
	# --- NOWOŚĆ: Tarcza blokująca kliknięcia/ataki przy otwartym UI ---
	# Jeśli okno jest otwarte (a klawisz nie był np. Pauzą z Global Inputs), ignorujemy akcję
	if is_input_locked:
		return
	# -------------------------------------------------------------------
	
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
	# --- NOWOŚĆ: Tarcza odcinająca sterowanie! ---
	# Jeśli menu (skrzynia/crafting) jest otwarte, ignorujemy wszystko poniżej.
	if is_input_locked:
		return false
	# -------------------------------------------------------------
	
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
	# Blokada Walki w pacifist zone
	if is_in_pacifist_zone and (event.is_action_pressed(INPUT_ATTACK) or event.is_action_pressed(INPUT_USE_ITEM)):
		print("Jesteś w Strefie Bezpiecznej! Walka zablokowana.")
	# ATAK
	elif event.is_action_pressed(INPUT_ATTACK):
		is_holding_attack = true
	elif event.is_action_released(INPUT_ATTACK):
		is_holding_attack = false
	
	# Ręczne przeładowanie (np. R)
	if event.is_action_pressed(INPUT_RELOAD): 
		var _item = inventory.get_current_item()
		if _item != null and _item.data.components != null:
			# Szukamy komponentu broni dystansowej
			for comp in _item.data.components:
				if comp is RangedWeaponComponent and comp.uses_ammunition:
					if inventory.reload_current_weapon():
						interaction_and_attack_stats_script.trigger_reload_cooldown(comp.reload_time)
					break # Znaleziono broń dystansową, kończymy pętlę

	# --- ZAAWANSOWANA ZMIANA AMUNICJI ---
	# TODO Skonfiguruj w InputMap np. klawisz "T" jako "ChangeAmmo" 
	#if event.is_action_pressed("ChangeAmmo"):
		#var _item = inventory.get_current_item()
		#if _item and _item.data is ItemDistanceWeapon and _item.data.uses_ammunition:
			#inventory.cycle_weapon_ammunition()
			## Zmiana pocisku wymusza przeładowanie, więc znowu dajemy cooldown!
			#interaction_and_attack_stats_script.trigger_reload_cooldown(_item.data.reload_time)
	
	# INTERAKCJA (Klawisz E - Otwieranie skrzyń, rozmowy itp.)
	if event.is_action_pressed(INPUT_INTERACT):
		if aim_controller.current_target != null:
			aim_controller.current_target.interact(self)
			
	# --- ZBIERANIE (Klawisz F - Zwijanie budowli) ---
	if event.is_action_pressed(INPUT_COLLECT):
		if aim_controller.current_target != null:
			# Wywołujemy naszą nową funkcję na celowniku
			if aim_controller.current_target.has_method("collect_interaction"):
				aim_controller.current_target.collect_interaction(self)

	# UŻYCIE PRZEDMIOTU (lub wejście w tryb budowy)
	if event.is_action_pressed(INPUT_USE_ITEM):
		var _item = inventory.get_current_item()
		if _item != null and _item.data != null and _item.data.components != null:
			for comp in _item.data.components:
				
				# 1. Obsługa budowania (PlaceableComponent sam odpali _start_building)
				if comp is PlaceableComponent:
					comp.try_execute(self, self, _item)
					break
					
				# 2. Obsługa konsumpcji (Zabezpieczona zegarem ataku)
				elif comp is ConsumableComponent:
					if interaction_and_attack_stats_script.can_attack():
						# Jeśli try_execute zwróci false, warunki nie zostały spełnione
						var success = comp.try_execute(self, self, _item)
						if not success:
							print("Nie można użyć przedmiotu! Warunki niespełnione.")
							# Tutaj możesz w przyszłości dodać np. dźwięk błędu z UI
					break

func _handle_building_inputs(event: InputEvent) -> void:
	# W trybie budowy atak = postawienie obiektu
	if event.is_action_pressed(INPUT_ATTACK):
		if builder_component.try_place_object():
			# --- NAPRAWA: Nowy system zużywania przedmiotów ---
			var current_item = inventory.get_current_item()
			if current_item != null:
				current_item.consume_amount(1)
				inventory.clean_dead_items()
			# --------------------------------------------------
			_cancel_building() # Wychodzimy z trybu budowy po udanym postawieniu
	
	# Obracanie obiektu
	if event.is_action_pressed(INPUT_ROTATE):
		builder_component.rotate_object()

	# Anulowanie budowy (PPM lub ponowne wciśnięcie przycisku użycia)
	if event.is_action_pressed(INPUT_INTERACT) or event.is_action_pressed(INPUT_USE_ITEM):
		_cancel_building()

func _start_building(placeable_comp: PlaceableComponent) -> void:
	if not builder_component:
		push_error("BŁĄD KRYTYCZNY: Nie znaleziono węzła BuilderComponent w Graczu!")
		return
		
	# Zlecenie budowy bezpośrednio do Buildera (przekazujemy KOMPONENT, a nie item_data)
	if builder_component.start_building(placeable_comp):
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
	var current_item = inventory.get_current_item()
	
	# Aktualizacja ręki gracza (itemu w ręce)
	if current_item != null:
		held_item_visual.texture = current_item.data.item_icon
		held_item_visual.show() 
	else:
		held_item_visual.texture = null
		held_item_visual.hide() 
	
	# ODCZYT STATYSTYK Z KOMPONENTÓW
	interaction_and_attack_stats_script.actual_extra_effects = []
	interaction_and_attack_stats_script.actual_attack_data = interaction_and_attack_stats_script.hand_attack_data # Domyślnie na pięści
	
	if current_item != null and current_item.data.components != null:
		var has_custom_cooldown = false
		for comp in current_item.data.components:
			if comp is MeleeWeaponComponent:
				interaction_and_attack_stats_script.change_item_cooldown(comp.use_cooldown)
				if comp.attack_data != null:
					interaction_and_attack_stats_script.actual_attack_data = comp.attack_data
				interaction_and_attack_stats_script.actual_extra_effects = comp.effects
				has_custom_cooldown = true
				break
			elif comp is RangedWeaponComponent:
				interaction_and_attack_stats_script.change_item_cooldown(comp.use_cooldown)
				if comp.attack_data != null:
					interaction_and_attack_stats_script.actual_attack_data = comp.attack_data
				interaction_and_attack_stats_script.actual_extra_effects = comp.weapon_effects
				has_custom_cooldown = true
				break
			# UWAGA: ConsumableComponent i PlaceableComponent celowo pomijamy w tej pętli, 
			# dzięki czemu trzymając jedzenie/surowiec, gracz zachowuje cooldown i statystyki "pięści"!
				
		if not has_custom_cooldown:
			interaction_and_attack_stats_script.change_item_cooldown(interaction_and_attack_stats_script.hand_attack_cooldown)
	else:
		interaction_and_attack_stats_script.change_item_cooldown(interaction_and_attack_stats_script.hand_attack_cooldown)
	
	# ZABEZPIECZENIE TRYBU BUDOWANIA
	if current_state == PlayerState.BUILDING:
		var is_placeable = false
		if current_item != null and current_item.data.components != null:
			for comp in current_item.data.components:
				if comp is PlaceableComponent:
					is_placeable = true
					break
		if not is_placeable:
			_cancel_building()

## Wywołuje się podczas wyrzucania przedmiotu (fizyczne okodowanie Noda).
func _on_inventory_item_dropped(dropped_instance: ItemInstance, is_thrown: bool):
	if item_thrower_component:
		# Zabezpieczamy pobranie kierunku z pada
		var aim_target = Vector2.ZERO
		if aim_controller and aim_controller.aim_scanner:
			aim_target = aim_controller.aim_scanner.target_position
			
		# Delegujemy całą resztę do komponentu
		item_thrower_component.handle_item_drop(self, dropped_instance, is_thrown, is_using_mouse, aim_target)
	else:
		push_error("BŁĄD: Ekwipunek wyrzucił przedmiot, ale Gracz nie ma przypisanego ItemThrowerComponent!")

# Nadpisanie bazowej funkcji z CharacterEntity
func respawn_sequence() -> void:
	# 1. Odpalamy całą logikę bazową (leczenie, zerowanie prędkości, usuwanie efektów)
	super() 
	
	print("Gracz: Inicjalizuję respawn powiązany z mapą...")
	
	# 2. Przekazanie obsługi położenia do Map, 
	# abyśmy przenieśli się też wewnątrz węzłów pokoi, a nie tylko wizualnie
	var level_manager = get_tree().get_first_node_in_group("Map")
	if level_manager:
		if level_manager.has_method("handle_player_respawn"):
			level_manager.handle_player_respawn(self)
	else:
		push_warning("Nie znaleziono Map podczas respawnu!")

#endregion

#region System ataku

## Obsługa ataku
func perform_attack() -> void:
	var current_item = inventory.get_current_item()
	var target_enemy = aim_controller.get_target_node()
	
	if target_enemy == null:
		return
		
	var has_los = aim_controller.has_line_of_sight(target_enemy)
	
	# Gracz po prostu mówi: "Komponencie, uderz tym, co trzymam. Masz tu mój ekwipunek!"
	if attack_component:
		attack_component.execute_attack(
			self, 
			target_enemy, 
			current_item, 
			inventory, # <--- WSTRZYKUJEMY EKWIPUNEK
			interaction_and_attack_stats_script,
			has_los
		)

# Zwraca aktualny zasięg ataku w zależności od przedmiotu
func get_current_attack_range() -> float:
	return float(interaction_and_attack_stats_script.get_total_range())

#endregion
