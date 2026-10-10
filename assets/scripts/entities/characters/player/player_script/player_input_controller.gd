class_name PlayerInputController
extends RefCounted

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")

const INPUT_AIM_LEFT = "AimLeft"
const INPUT_AIM_RIGHT = "AimRight"
const INPUT_AIM_UP = "AimUp"
const INPUT_AIM_DOWN = "AimDown"
const INPUT_DROP_ITEM = "DropItem"
const INPUT_FULL_DROP_ITEM_KEY = "FullDropItemKey"
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
const INPUT_ROTATE = "RotateBuilding"

var is_using_mouse: bool = true
var is_holding_attack: bool = false
var _is_holding_drop: bool = false
var _has_dropped_serial: bool = false
var _drop_hold_time: float = 0.0
var _current_drop_timer: float = 0.0

var _inventory: Inventory
var _aim_controller: PlayerAimController
var _builder_component: BuilderComponent
var _attack_stats: InteractionAndAttackStatsComponent

const DROP_INITIAL_DELAY := 0.4
const DROP_SERIAL_COOLDOWN := 0.1

func initialize(
	inventory: Inventory,
	aim_controller: PlayerAimController,
	builder_component: BuilderComponent,
	attack_stats: InteractionAndAttackStatsComponent
) -> void:
	_inventory = inventory
	_aim_controller = aim_controller
	_builder_component = builder_component
	_attack_stats = attack_stats

func handle_unhandled_input(
	player: Node2D,
	event: InputEvent,
	is_input_locked: bool,
	is_respawning: bool,
	is_building: bool,
	is_in_pacifist_zone: bool
) -> void:
	if is_respawning:
		return

	_detect_input_device(event)
	if _handle_global_inputs(player, event, is_input_locked, is_respawning, is_building):
		return
	if is_input_locked:
		return

	if is_building:
		_handle_building_inputs(player, event)
	else:
		_handle_default_inputs(player, event, is_in_pacifist_zone)

func process_item_dropping(delta: float) -> void:
	if Input.is_action_just_pressed(INPUT_FULL_DROP_ITEM_KEY):
		_inventory.drop_current_item(true)
		_reset_drop_state()
		return

	if Input.is_action_just_pressed(INPUT_DROP_ITEM):
		_is_holding_drop = true
		_has_dropped_serial = false
		_drop_hold_time = 0.0
		_current_drop_timer = 0.0

	if Input.is_action_pressed(INPUT_DROP_ITEM) and _is_holding_drop:
		_drop_hold_time += delta
		if _drop_hold_time >= DROP_INITIAL_DELAY:
			if _current_drop_timer <= 0.0:
				_inventory.drop_current_item(false)
				_has_dropped_serial = true
				_current_drop_timer = DROP_SERIAL_COOLDOWN
			else:
				_current_drop_timer -= delta

	if Input.is_action_just_released(INPUT_DROP_ITEM):
		if (
			_is_holding_drop
			and not _has_dropped_serial
			and _drop_hold_time < DROP_INITIAL_DELAY
		):
			_inventory.drop_current_item(false)
		_reset_drop_state()

func reset_transient_input() -> void:
	is_holding_attack = false
	_reset_drop_state()

func _reset_drop_state() -> void:
	_is_holding_drop = false
	_has_dropped_serial = false
	_drop_hold_time = 0.0
	_current_drop_timer = 0.0

func _detect_input_device(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		is_using_mouse = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.2:
		is_using_mouse = false
	elif event is InputEventJoypadButton:
		is_using_mouse = false
	elif event is InputEventKey and event.is_pressed():
		if (
			event.is_action(INPUT_AIM_LEFT)
			or event.is_action(INPUT_AIM_RIGHT)
			or event.is_action(INPUT_AIM_UP)
			or event.is_action(INPUT_AIM_DOWN)
		):
			is_using_mouse = false

func _handle_global_inputs(
	player: Node2D,
	event: InputEvent,
	is_input_locked: bool,
	is_respawning: bool,
	is_building: bool
) -> bool:
	if is_input_locked:
		return false

	if event.is_action_pressed("Game_Pause"):
		if is_building:
			player.call("_cancel_building")
			player.get_viewport().set_input_as_handled()
		return true

	if event.is_action_pressed(INPUT_RESPAWN):
		if is_respawning:
			return true
		var level_manager := player.get_tree().get_first_node_in_group("Map")
		if level_manager and level_manager.has_method("is_transition_active"):
			if level_manager.is_transition_active():
				print("Blokada: Menedżer Przejść jest zajęty animacją ekranu!")
				return true
		elif TransitionManager.is_transition_active():
			print("Blokada: Menedżer Przejść jest zajęty animacją ekranu!")
			return true
		player.call_deferred("respawn_sequence")
		return true

	if event.is_action_pressed(INPUT_TOGGLE_ENEMY_PRIO):
		_aim_controller.auto_enemy_selector = not _aim_controller.auto_enemy_selector
		_aim_controller.auto_lock_closest_enemy = not _aim_controller.auto_lock_closest_enemy
		if _aim_controller.auto_enemy_selector:
			print("Auto-Enemy Selector With Locking Closest Enemy: WŁĄCZONY")
		else:
			print("Auto-Enemy Selector With Locking Closest Enemy: WYŁĄCZONY")
			_aim_controller.clear_gamepad_target()
		return true

	for index in range(1, 10):
		if event.is_action_pressed(INPUT_INV_SLOT_PREFIX + str(index)):
			_inventory.select_item(index - 1)
			return true

	if event.is_action_pressed(INPUT_INV_SCROLL_DOWN):
		_inventory.scroll_inventory(1)
		return true
	if event.is_action_pressed(INPUT_INV_SCROLL_UP):
		_inventory.scroll_inventory(-1)
		return true

	return false

func _handle_default_inputs(
	player: Node2D,
	event: InputEvent,
	is_in_pacifist_zone: bool
) -> void:
	if is_in_pacifist_zone and event.is_action_pressed(INPUT_ATTACK):
		print("Jesteś w Strefie Bezpiecznej! Walka zablokowana.")
	elif event.is_action_pressed(INPUT_ATTACK):
		is_holding_attack = true
	elif event.is_action_released(INPUT_ATTACK):
		is_holding_attack = false

	if event.is_action_pressed(INPUT_RELOAD):
		var item: ItemInstance = _inventory.get_current_item()
		if item != null and item.data.components != null:
			for component in item.data.components:
				if component is RangedWeaponComponent and component.uses_ammunition:
					var reload_succeeded := _inventory.reload_current_weapon()
					if reload_succeeded:
						_attack_stats.trigger_reload_cooldown(component.reload_time)
					if player.has_method("play_reload_feedback"):
						player.call("play_reload_feedback", reload_succeeded)
					break

	if event.is_action_pressed(INPUT_INTERACT):
		if _aim_controller.current_target != null:
			_aim_controller.current_target.interact(player)

	if event.is_action_pressed(INPUT_COLLECT):
		if (
			_aim_controller.current_target != null
			and _aim_controller.current_target.has_method("collect_interaction")
		):
			_aim_controller.current_target.collect_interaction(player)

	if event.is_action_pressed(INPUT_USE_ITEM):
		var item: ItemInstance = _inventory.get_current_item()
		if item == null or item.data == null or item.data.components == null:
			return

		for component in item.data.components:
			if component is PlaceableComponent:
				component.try_execute(player, player, item)
				break
			elif component is ThrowableComponent:
				if is_in_pacifist_zone:
					print("Jesteś w Strefie Bezpiecznej! Walka zablokowana.")
					break
				if _attack_stats.can_attack():
					component.try_execute(player, player, item)
				break
			elif component is ConsumableComponent:
				if is_in_pacifist_zone and component.has_offensive_effects():
					print("Jesteś w Strefie Bezpiecznej! Walka zablokowana.")
					break
				if _attack_stats.can_attack() and not component.try_execute(player, player, item):
					print("Nie można użyć przedmiotu! Warunki niespełnione.")
				break

func _handle_building_inputs(player: Node2D, event: InputEvent) -> void:
	if event.is_action_pressed(INPUT_ATTACK):
		if _builder_component.try_place_object():
			var current_item: ItemInstance = _inventory.get_current_item()
			if current_item != null:
				if current_item.data != null and current_item.data.components != null:
					for component in current_item.data.components:
						if component is PlaceableComponent:
							FeedbackDispatcherType.play_for_actor(
								component.use_feedback,
								player,
								player
							)
							break
				current_item.consume_amount(1)
				_inventory.clean_dead_items()
			player.call("_cancel_building")

	if event.is_action_pressed(INPUT_ROTATE):
		_builder_component.rotate_object()

	if event.is_action_pressed(INPUT_INTERACT) or event.is_action_pressed(INPUT_USE_ITEM):
		player.call("_cancel_building")
