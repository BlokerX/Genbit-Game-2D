## Połączony modularnie skrypt dla gracza ##
extends CharacterEntity
class_name PlayerCharacter

const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")
const PlayerPassiveEffectControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_passive_effect_controller.gd"
)
const PlayerHeldItemControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_held_item_controller.gd"
)
const PlayerInputControllerType = preload(
	"res://assets/scripts/entities/characters/player/player_script/player_input_controller.gd"
)
const PlayerFeedbackControllerType = preload(
	"res://assets/scripts/audio_system/player_feedback_controller.gd"
)

#region STAŁE WEJŚCIA I FIZYKI (Wyeliminowanie magicznych liczb i stringów)
const INPUT_LEFT = "Left"
const INPUT_RIGHT = "Right"
const INPUT_UP = "Up"
const INPUT_DOWN = "Down"

## Maksymalna prędkość nadawana popychanym przedmiotom (chroni przed wbijaniem itemów w ściany).
const MAX_PUSHED_RIGIDBODY_SPEED: float = 120.0
## Mnożnik płynnego przepychania postaci AI przy bezpośrednim kontakcie.
const AI_PUSH_STEP_MULTIPLIER: float = 0.2
## Czas oczekiwania (w sekundach) na ekranie śmierci przed przejściem do respawnu.
const DEATH_SCREEN_DELAY_SEC: float = 1.5
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
	return inventory

@onready var aim_controller: PlayerAimController = $AimController
#endregion

#region Obsługa przedmiotów w inventory
@onready var held_item_visual: Sprite2D = $HeldItemHandler/HeldItemVisual
var _passive_effect_controller: PlayerPassiveEffectControllerType
var _held_item_controller: PlayerHeldItemControllerType
var _input_controller: PlayerInputControllerType
@onready var _feedback_controller: PlayerFeedbackControllerType = $PlayerFeedbackController

var is_using_mouse: bool:
	get:
		return _input_controller.is_using_mouse if _input_controller != null else true
	set(value):
		if _input_controller != null:
			_input_controller.is_using_mouse = value
#endregion

#region Pchnięcia
## Siła z jaką gracz popycha obiekty fizyczne (5.0-ciężki tłum, 10.0-standard, 20.0-taran)
@export var push_force: float = 10.0
#endregion

#region System Stanów Gracza
enum PlayerState { DEFAULT, BUILDING }
var current_state: PlayerState = PlayerState.DEFAULT
var is_input_locked: bool = false
var is_in_pacifist_zone: bool = false
## Zapamiętuje dokładne miejsce zgonu, aby przedmioty wyrzucane po śmierci zawsze wypadały przy krzyżu.
var _last_death_position: Vector2 = Vector2.INF
#endregion

#region Główne funkcje silnikowe
func _ready() -> void:
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

	super()
	_passive_effect_controller = PlayerPassiveEffectControllerType.new()
	_passive_effect_controller.initialize(self, effects_collector)
	if is_instance_valid(_feedback_controller):
		_feedback_controller.initialize(self)
	_held_item_controller = PlayerHeldItemControllerType.new()
	_held_item_controller.initialize(
		held_item_visual, player_light, interaction_and_attack_stats_script
	)
	_input_controller = PlayerInputControllerType.new()
	_input_controller.initialize(
		inventory,
		aim_controller,
		builder_component,
		interaction_and_attack_stats_script
	)

	if attack_component and not attack_component.spawn_projectile_requested.is_connected(
		_on_spawn_requested
	):
		attack_component.spawn_projectile_requested.connect(_on_spawn_requested)

	if item_thrower_component and not item_thrower_component.entity_spawn_requested.is_connected(
		_on_spawn_requested
	):
		item_thrower_component.entity_spawn_requested.connect(_on_spawn_requested)

	#region Linkowanie zdarzeń
	if inventory:
		inventory.inventory_updated.connect(on_inventory_update)
		on_inventory_update()
		inventory.item_dropped.connect(_on_inventory_item_dropped)

		inventory.held_passives_changed.connect(_sync_held_passives)
		inventory.equipment_passives_changed.connect(_sync_equip_passives)
		inventory.inventory_passives_changed.connect(_sync_inventory_passives)

		inventory.inventory_updated.emit()
	#endregion

	EventBus.ui_state_changed.connect(_on_ui_state_changed)
	_on_ui_state_changed(EventBus.is_any_menu_open())

func _on_spawn_requested(node: Node2D, spawn_position: Vector2) -> void:
	entity_spawn_requested.emit(node, spawn_position)

## Zachowuje bazową logikę śmierci, zamraża pozycję zgonu dla dropu i odtwarza oprawę gracza.
func _on_character_died() -> void:
	if not is_dead and not (has_meta("is_immortal") and get_meta("is_immortal") == true):
		_last_death_position = global_position
		if is_instance_valid(_feedback_controller):
			_feedback_controller.play_death()
	super()

## Zachowuje obsługę efektu bazowego i uruchamia reakcję na jego faktyczne przyjęcie.
func receive_effect(effect: Effect) -> bool:
	var effect_applied: bool = super.receive_effect(effect)
	if effect_applied and is_instance_valid(_feedback_controller):
		_feedback_controller.play_received_effect(effect)
	return effect_applied

## Przekazuje początek i koniec mrozu do ekranowej oprawy gracza.
func set_freeze_feedback_active(is_active: bool) -> void:
	if is_instance_valid(_feedback_controller):
		_feedback_controller.set_freeze_feedback_active(is_active)

## Wywoływane przez efekty obrażeń po trafieniu zadanym przez gracza.
func notify_damage_dealt(target: Node2D) -> void:
	if is_instance_valid(_feedback_controller):
		_feedback_controller.play_damage_dealt(target)

## Przekazuje wynik przeładowania do kontrolera oprawy gracza.
func play_reload_feedback(succeeded: bool) -> void:
	if is_instance_valid(_feedback_controller):
		_feedback_controller.play_reload(succeeded)

## Odtwarza oprawę udanego zebrania przedmiotu ze świata.
func play_item_pickup_feedback() -> void:
	if is_instance_valid(_feedback_controller):
		_feedback_controller.play_item_pickup()

## Odtwarza oprawę wyrzucenia przedmiotu z dowolnego panelu ekwipunku.
func play_item_drop_feedback() -> void:
	if is_instance_valid(_feedback_controller):
		_feedback_controller.play_item_drop()

## Punkt wejścia dla komponentów przedmiotów z własną oprawą w Inspektorze (SOLID - OCP).
func play_item_feedback(cue: FeedbackCueType, target: Node2D) -> void:
	if not is_instance_valid(_feedback_controller):
		return
	if cue != null:
		_feedback_controller.play_item_use(cue, target)
		return
	var current_item: ItemInstance = inventory.get_current_item() if inventory != null else null
	if _item_has_weapon_component(current_item):
		_feedback_controller.play_combat(target)
		return
	_feedback_controller.play_item_use(null, target)

func _item_has_weapon_component(item_inst: ItemInstance) -> bool:
	if item_inst == null or item_inst.data == null or item_inst.data.components == null:
		return false
	for component in item_inst.data.components:
		if component != null and component.is_weapon_component():
			return true
	return false

func _on_ui_state_changed(is_open: bool) -> void:
	is_input_locked = is_open
	if is_open and _input_controller != null:
		_input_controller.reset_transient_input()

func _process(delta: float) -> void:
	super(delta)

func _physics_process(delta: float) -> void:
	super(delta)
	if is_respawning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	#region Move Procedure
	var horizontal: float = Input.get_axis(INPUT_LEFT, INPUT_RIGHT)
	var vertical: float = Input.get_axis(INPUT_UP, INPUT_DOWN)

	if movement_universal_script != null:
		velocity = movement_universal_script.movement_procedure(delta, velocity, Vector2(horizontal, vertical))
	else:
		velocity = Vector2.ZERO

	_update_sprite_direction(Vector2(horizontal, vertical))
	move_and_slide()
	if is_instance_valid(_feedback_controller):
		_feedback_controller.process_movement_feedback(delta, get_real_velocity())
	#endregion

	var is_building: bool = (current_state == PlayerState.BUILDING)
	var current_range: float = builder_component.build_range if is_building else get_current_attack_range()

	aim_controller.process_aiming(_input_controller.is_using_mouse, current_range, is_building)
	_handle_pushing()
	_input_controller.process_item_dropping(delta)

	if interaction_and_attack_stats_script != null:
		if is_in_pacifist_zone:
			_input_controller.is_holding_attack = false
		interaction_and_attack_stats_script.interaction_cooldown_process(delta)
		if _input_controller.is_holding_attack and interaction_and_attack_stats_script.can_attack():
			perform_attack()

func _handle_pushing() -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		# 1. Popychanie zwykłych obiektów fizycznych (z bezpiecznym limitem prędkości!)
		if collider is RigidBody2D:
			var rigid: RigidBody2D = collider as RigidBody2D
			if rigid.linear_velocity.length() < MAX_PUSHED_RIGIDBODY_SPEED:
				rigid.apply_central_impulse(-collision.get_normal() * push_force)

		# 2. Popychanie Wrogów - NATURALNE PRZEPYCHANIE
		elif collider is AICharacterEntity:
			(collider as AICharacterEntity).move_and_collide(-collision.get_normal() * (push_force * AI_PUSH_STEP_MULTIPLIER))

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
	if builder_component.start_building(placeable_comp):
		current_state = PlayerState.BUILDING
		_input_controller.is_holding_attack = false

func _cancel_building() -> void:
	if builder_component:
		builder_component.stop_building()
	_input_controller.reset_transient_input()
	current_state = PlayerState.DEFAULT
#endregion
#endregion

#region Obsługa sygnałów
func on_inventory_update() -> void:
	var current_item: ItemInstance = inventory.get_current_item()
	_held_item_controller.refresh(current_item)

	if current_state == PlayerState.BUILDING:
		var is_placeable: bool = false
		if current_item != null and current_item.data.components != null:
			for comp in current_item.data.components:
				if comp is PlaceableComponent:
					is_placeable = true
					break
		if not is_placeable:
			_cancel_building()

## Wywołuje się podczas wyrzucania przedmiotu. Gwarantuje użycie pozycji śmierci, jeśli gracz zginął.
func _on_inventory_item_dropped(dropped_instance: ItemInstance, is_thrown: bool) -> void:
	if item_thrower_component:
		var throw_direction: Vector2 = Vector2.ZERO
		if aim_controller and aim_controller.aim_scanner:
			var target_pos: Vector2 = aim_controller.aim_scanner.global_position
			throw_direction = global_position.direction_to(target_pos).normalized()

		var drop_origin: Vector2 = (
			_last_death_position
			if (is_dead or is_respawning) and _last_death_position != Vector2.INF
			else global_position
		)

		item_thrower_component.handle_item_drop(
			self,
			dropped_instance,
			is_thrown,
			_input_controller.is_using_mouse,
			throw_direction,
			drop_origin
		)
		if (
			item_thrower_component.item_pickup_scene != null
			and is_instance_valid(_feedback_controller)
		):
			_feedback_controller.play_item_drop()
	else:
		push_error("BŁĄD: Ekwipunek wyrzucił przedmiot, ale Gracz nie ma przypisanego ItemThrowerComponent!")

func respawn_sequence() -> void:
	if is_respawning:
		return
	is_respawning = true
	_input_controller.reset_transient_input()
	var scene_tree: SceneTree = get_tree()

	# --- FAZA 1: RATOWANIE ŻYCIA I ZAMROŻENIE ---
	velocity = Vector2.ZERO
	set_physics_process(false)
	purge_absolutely_everything()

	if is_dead:
		EventBus.player_died.emit()
		await scene_tree.create_timer(DEATH_SCREEN_DELAY_SEC).timeout
	else:
		print("Gracz użył manualnego respawnu - pomijam fazę leżenia.")
	if not is_inside_tree():
		return

	# --- FAZA 2: ZLECENIE PRZENOSIN MAPIE ---
	process_mode = Node.PROCESS_MODE_DISABLED
	print("Gracz: Inicjalizuję respawn powiązany z mapą...")

	var level_manager: Node = scene_tree.get_first_node_in_group("Map")
	if is_instance_valid(level_manager):
		if level_manager.has_method("handle_player_respawn"):
			await level_manager.handle_player_respawn(self)
	else:
		push_warning("Nie znaleziono Map podczas respawnu!")
	if not is_inside_tree():
		return

	# --- FAZA 3: KONIEC ODRADZANIA ---
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)

	await scene_tree.physics_frame
	if not is_inside_tree():
		return
	await scene_tree.physics_frame
	if not is_inside_tree():
		return

	is_respawning = false
	_last_death_position = Vector2.INF
	if inventory:
		inventory.refresh_passives()
#endregion

#region System ataku
func perform_attack() -> void:
	var current_item: ItemInstance = inventory.get_current_item()
	var target_enemy: Node2D = aim_controller.get_target_node()
	if target_enemy == null:
		return

	var has_los: bool = aim_controller.has_line_of_sight(target_enemy)

	if attack_component:
		var attack_succeeded: bool = attack_component.execute_attack(
			self, 
			target_enemy, 
			current_item, 
			inventory,
			interaction_and_attack_stats_script,
			has_los
		)
		var is_using_combat_item: bool = _item_has_weapon_component(current_item)
		if (
			attack_succeeded
			and not is_using_combat_item
			and is_instance_valid(_feedback_controller)
		):
			_feedback_controller.play_combat(target_enemy)

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
