## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

const PlayerPassiveEffectControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_passive_effect_controller.gd"
)
const PlayerHeldItemControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_held_item_controller.gd"
)
const PlayerInputControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_input_controller.gd"
)

#region STAŁE WEJŚCIA (Wyeliminowanie magicznych stringów)

const INPUT_LEFT = "Left"
const INPUT_RIGHT = "Right"
const INPUT_UP = "Up"
const INPUT_DOWN = "Down"

#endregion

@onready var player_light: PointLight2D = $PointLight2D

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

#region Obsługa przedmiotów w inventory

@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual
var _passive_effect_controller: PlayerPassiveEffectControllerType
var _held_item_controller: PlayerHeldItemControllerType
var _input_controller: PlayerInputControllerType

var is_using_mouse: bool:
	get:
		return _input_controller.is_using_mouse if _input_controller != null else true
	set(value):
		if _input_controller != null:
			_input_controller.is_using_mouse = value

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
	if (
		movement_universal_script == null
		or health_stats_script == null
		or interaction_and_attack_stats_script == null
		or inventory == null
		or aim_controller == null
		or held_item_visual == null
		or player_light == null
	):
		push_error(
			"PlayerCharacter: Brakuje wymaganego komponentu ruchu, zdrowia, statystyk, "
			+ "ekwipunku, celownika, wizualizacji przedmiotu lub światła."
		)
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	
	# Gracz nie umiera na zawsze
	destroy_entity_after_die = false 
	
	# Health points bar initialization
	super()
	_passive_effect_controller = PlayerPassiveEffectControllerType.new()
	_passive_effect_controller.initialize(self, effects_collector)
	_held_item_controller = PlayerHeldItemControllerType.new()
	_held_item_controller.initialize(
		held_item_visual,
		player_light,
		interaction_and_attack_stats_script
	)
	_input_controller = PlayerInputControllerType.new()
	_input_controller.initialize(
		inventory,
		aim_controller,
		builder_component,
		interaction_and_attack_stats_script
	)
	
	# Przekazywanie sygnału spawnowania pocisku wyżej, do menedżera mapy
	if attack_component and not attack_component.spawn_projectile_requested.is_connected(
		_on_spawn_requested
	):
		attack_component.spawn_projectile_requested.connect(_on_spawn_requested)
	
	# Przekazywanie sygnału spawnowania z wyrzucania przedmiotów wyżej
	if item_thrower_component and not item_thrower_component.entity_spawn_requested.is_connected(
		_on_spawn_requested
	):
		item_thrower_component.entity_spawn_requested.connect(_on_spawn_requested)
	
	#region Linkowanie zdarzeń
	if inventory:
		inventory.inventory_updated.connect(on_inventory_update)
		on_inventory_update()
		inventory.item_dropped.connect(_on_inventory_item_dropped)
		
		# --- NOWE PODŁĄCZENIE (Zasada SRP) ---
		inventory.held_passives_changed.connect(_sync_held_passives)
		inventory.equipment_passives_changed.connect(_sync_equip_passives)
		inventory.inventory_passives_changed.connect(_sync_inventory_passives)
		
		inventory.inventory_updated.emit()
	#endregion
	
	#setup_complete.emit()
	
	# Nasłuch na zamykanie/otwieranie interfejsu
	EventBus.ui_state_changed.connect(_on_ui_state_changed)
	_on_ui_state_changed(EventBus.is_any_menu_open())

func _on_spawn_requested(node: Node2D, spawn_position: Vector2) -> void:
	entity_spawn_requested.emit(node, spawn_position)

func _on_ui_state_changed(is_open: bool) -> void:
	is_input_locked = is_open
	if is_open and _input_controller != null:
		_input_controller.reset_transient_input()

func _process(delta):
	# Update health gui data.
	super(delta)

func _physics_process(delta):
	super(delta)

	if is_respawning:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
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
	
	aim_controller.process_aiming(_input_controller.is_using_mouse, current_range, is_building)
	
	# Obsługa popychania TODO
	_handle_pushing()
	# Obsługa wyrzucania itemów
	_input_controller.process_item_dropping(delta)
	
	# Zawsze aktualizujemy licznik cooldownu (bezpieczne wywołanie)
	if interaction_and_attack_stats_script != null:
		if is_in_pacifist_zone:
			_input_controller.is_holding_attack = false
		interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		
		# Jeśli gracz trzyma przycisk ataku i skończył się cooldown -> wykonaj uderzenie!
		if _input_controller.is_holding_attack and interaction_and_attack_stats_script.can_attack():
			perform_attack()

func _handle_pushing() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 1. Popychanie zwykłych obiektów fizycznych (upuszczony loot, skrzynki fizyczne)
		if collider is RigidBody2D:
			collider.apply_central_impulse(-collision.get_normal() * push_force)
			
		# 2. Popychanie Wrogów (np. pająków) - NATURALNE PRZEPYCHANIE
		elif collider is AICharacterEntity:
			# Zamiast wstrzykiwać prędkość, wymuszamy gładkie przesunięcie o ułamek piksela.
			# Mnożnik 0.2 przy push_force (10.0) przesuwa wroga o 2 piksele na klatkę.
			# Dzięki użyciu move_and_collide pająk nie przejdzie przez ścianę, jeśli go do niej dociśniesz!
			collider.move_and_collide(-collision.get_normal() * (push_force * 0.2))

# --- WYŁAPYWANIE AKCJI BEZ PRZEBIJANIA UI ---
func _unhandled_input(event: InputEvent) -> void:
	_input_controller.handle_unhandled_input(
		self,
		event,
		is_input_locked,
		is_respawning,
		current_state == PlayerState.BUILDING,
		is_in_pacifist_zone
	)

#region Methods sections

func _start_building(placeable_comp: PlaceableComponent) -> void:
	if not builder_component:
		push_error("BŁĄD KRYTYCZNY: Nie znaleziono węzła BuilderComponent w Graczu!")
		return
		
	# Zlecenie budowy bezpośrednio do Buildera (przekazujemy KOMPONENT, a nie item_data)
	if builder_component.start_building(placeable_comp):
		current_state = PlayerState.BUILDING
		_input_controller.is_holding_attack = false
		print("DEBUG: Wszedłem w stan BUILDING i odpaliłem ducha!")

func _cancel_building() -> void:
	if builder_component:
		builder_component.stop_building()
	_input_controller.reset_transient_input()
	# POWRÓT DO STANU DOMYŚLNEGO
	current_state = PlayerState.DEFAULT
	print("DEBUG: Anulowano budowę, wróciłem do stanu DEFAULT.")

#endregion

#endregion

#region Obsługa sygnałów

## Wywołuje się kiedy ekwipunek jest aktualizowany.
func on_inventory_update() -> void:
	var current_item: ItemInstance = inventory.get_current_item()
	_held_item_controller.refresh(current_item)

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
		var throw_direction := Vector2.ZERO
		
		# Zamiana celu na ZNORMALIZOWANY KIERUNEK
		if aim_controller and aim_controller.aim_scanner:
			var target_pos = aim_controller.aim_scanner.global_position
			throw_direction = global_position.direction_to(target_pos).normalized()
			
		# Teraz Twój item_thrower_component otrzymuje dokładny kierunek lotu
		item_thrower_component.handle_item_drop(
			self,
			dropped_instance,
			is_thrown,
			_input_controller.is_using_mouse,
			throw_direction
		)
	else:
		push_error("BŁĄD: Ekwipunek wyrzucił przedmiot, ale Gracz nie ma przypisanego ItemThrowerComponent!")

# Nadpisanie bazowej funkcji z CharacterEntity
func respawn_sequence() -> void:
	if is_respawning:
		return
	is_respawning = true
	_input_controller.reset_transient_input()
	var scene_tree := get_tree()
	
	# --- FAZA 1: RATOWANIE ŻYCIA I ZAMROŻENIE (Na widocznym ekranie) ---
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Czyścimy efekty i leczymy gracza NATYCHMIAST, by nic nas nie dobiło w trakcie animacji
	purge_absolutely_everything()
	
	# Sprawdzamy czy trafiliśmy tu z powodu utraty HP, czy z guzika:
	if is_dead:
		EventBus.player_died.emit()
		await scene_tree.create_timer(1.5).timeout
	else:
		# Manualny respawn - pomijamy timer, następuje błyskawiczne wygaszenie
		print("Gracz użył manualnego respawnu - pomijam fazę leżenia.")
	if not is_inside_tree():
		return
	
	# --- FAZA 2: ZLECENIE PRZENOSIN MAPIE ---
	process_mode = Node.PROCESS_MODE_DISABLED
	print("Gracz: Inicjalizuję respawn powiązany z mapą...")
	
	var level_manager := scene_tree.get_first_node_in_group("Map")
	if is_instance_valid(level_manager):
		if level_manager.has_method("handle_player_respawn"):
			# Await zatrzymuje gracza do momentu pełnego pojawienia się i rozjaśnienia mapy
			await level_manager.handle_player_respawn(self)
	else:
		push_warning("Nie znaleziono Map podczas respawnu!")
	if not is_inside_tree():
		return
	
	# --- FAZA 3: KONIEC ODRADZANIA (Ekran już jest jasny) ---
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	
	# Czekamy równe dwie klatki fizyki zachowując tarczę "is_respawning".
	# Dzięki temu, gdy gracz wyląduje na portalu/drzwiach, odrzucą one teleportację
	# ułamek sekundy przed tym, jak oddamy graczowi pełną kontrolę!
	await scene_tree.physics_frame
	if not is_inside_tree():
		return
	await scene_tree.physics_frame
	if not is_inside_tree():
		return
	
	is_respawning = false

	if inventory:
		inventory.refresh_passives()

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

#region System Pasywnych Efektów i Zbroi (SOLID)

func _sync_held_passives() -> void:
	_passive_effect_controller.sync_held_passives(inventory)

func _sync_equip_passives() -> void:
	_passive_effect_controller.sync_equipment_passives(inventory)

func _sync_inventory_passives() -> void:
	_passive_effect_controller.sync_inventory_passives(inventory)

#endregion
