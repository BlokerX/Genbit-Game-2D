class_name InventoryCursorController
extends RefCounted

const InventorySlotInteractorType = preload("res://assets/scripts/ui/inventory_slot_interactor.gd")

var _ui_owner: Node
var _player_inventory: Inventory
var _slot_interactor: InventorySlotInteractorType
var _main_inventory_window: Control
var _crafting_ui: Control
var _cursor_item_rect: TextureRect
var _cursor_amount_label: Label

## Łączy wizualizację kursora i wyrzucanie przedmiotów z istniejącym interfejsem ekwipunku.
func initialize(
	ui_owner: Node,
	player_inventory: Inventory,
	slot_interactor: InventorySlotInteractorType,
	main_inventory_window: Control,
	crafting_ui: Control,
	cursor_item_rect: TextureRect,
	cursor_amount_label: Label
) -> void:
	if (
		ui_owner == null
		or player_inventory == null
		or slot_interactor == null
		or cursor_item_rect == null
		or cursor_amount_label == null
	):
		push_error("InventoryCursorController wymaga właściciela UI, ekwipunku i elementów kursora.")
		return

	_ui_owner = ui_owner
	_player_inventory = player_inventory
	_slot_interactor = slot_interactor
	_main_inventory_window = main_inventory_window
	_crafting_ui = crafting_ui
	_cursor_item_rect = cursor_item_rect
	_cursor_amount_label = cursor_amount_label

## Synchronizuje ikonę kursora i licznik stosu z przedmiotem trzymanym przez interaktor slotów.
func update_cursor_visuals() -> void:
	if not _is_initialized():
		return

	var held_item := _slot_interactor.held_item
	if held_item != null:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_cursor_item_rect.texture = held_item.data.item_icon
		_cursor_item_rect.show()
		var hand_amount = held_item.state.get("amount", 1)
		if hand_amount > 1:
			_cursor_amount_label.text = str(hand_amount)
			_cursor_amount_label.show()
		else:
			_cursor_amount_label.hide()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cursor_item_rect.texture = null
		_cursor_item_rect.hide()
		_cursor_amount_label.hide()

## Utrzymuje ikonę trzymanego przedmiotu na środku kursora myszy.
func update_cursor_position() -> void:
	if not _is_initialized() or _slot_interactor.held_item == null:
		return

	var viewport := _ui_owner.get_viewport()
	_cursor_item_rect.global_position = viewport.get_mouse_position() - (_cursor_item_rect.size / 2.0)

## Zwraca przedmiot trzymany kursorem do ekwipunku podczas zamykania interfejsu.
func return_held_item_to_inventory() -> void:
	if not _is_initialized() or _slot_interactor.held_item == null:
		return

	var remainder = _player_inventory.add_instance(_slot_interactor.held_item)
	if remainder != null:
		_player_inventory.item_dropped.emit(remainder, true)
	_slot_interactor.held_item = null
	update_cursor_visuals()

## Wyrzuca z kursora cały stos lub jedną sztukę przedmiotu do świata.
func drop_item_from_cursor(drop_all: bool = true) -> void:
	if not _is_initialized() or _slot_interactor.held_item == null:
		return

	var dropped_instance: ItemInstance
	if drop_all:
		dropped_instance = _slot_interactor.held_item
		_slot_interactor.held_item = null
	else:
		var held_item := _slot_interactor.held_item
		var hand_amount = held_item.state.get("amount", 1)
		var unique_data = held_item.data.duplicate(true)
		dropped_instance = ItemInstance.new(unique_data, 1)
		dropped_instance.state = held_item.state.duplicate(true)
		dropped_instance.state["amount"] = 1

		held_item.state["amount"] = hand_amount - 1
		if held_item.state["amount"] <= 0:
			_slot_interactor.held_item = null

	update_cursor_visuals()
	_execute_drop_in_world(dropped_instance)

## Wyrzuca trzymany przedmiot albo zawartość wskazanego slotu w wybranej ilości.
func try_drop_hovered_slot(drop_all: bool) -> void:
	if not _is_initialized():
		return

	if _slot_interactor.held_item != null:
		var held_item := _slot_interactor.held_item
		var hand_amount = held_item.state.get("amount", 1)
		var amount_to_drop = hand_amount if drop_all else 1
		var unique_data = held_item.data.duplicate(true)
		var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
		dropped_instance.state = held_item.state.duplicate(true)
		dropped_instance.state["amount"] = amount_to_drop
		held_item.state["amount"] = hand_amount - amount_to_drop
		if held_item.state["amount"] <= 0:
			_slot_interactor.held_item = null
		update_cursor_visuals()
		_execute_drop_in_world(dropped_instance)
		return

	var hovered = _ui_owner.get_viewport().gui_get_hovered_control()
	var target_slot_ui: InventorySlot = null
	while hovered != null:
		if hovered is InventorySlot:
			target_slot_ui = hovered
			break
		hovered = hovered.get_parent()

	if target_slot_ui != null:
		var parent_node = target_slot_ui.parent_reference
		var slot_idx = target_slot_ui.slot_index
		var target_slot: SlotData
		if parent_node is StorageComponent:
			target_slot = parent_node.slots[slot_idx]
		elif parent_node is Inventory:
			# --- NAPRAWA: Zrozumienie slotów zbroi i plecaka ('Q' na akcesoriach) ---
			if slot_idx <= -10:
				var equip_type = abs(slot_idx + 10)
				target_slot = parent_node.equipment_slots[equip_type]
			else:
				target_slot = parent_node.slots[slot_idx]

		if target_slot and not target_slot.is_empty():
			var slot_amount = target_slot.item.state.get("amount", 1)
			var amount_to_drop = slot_amount if drop_all else 1
			var unique_data = target_slot.item.data.duplicate(true)
			var dropped_instance = ItemInstance.new(unique_data, amount_to_drop)
			dropped_instance.state = target_slot.item.state.duplicate(true)
			dropped_instance.state["amount"] = amount_to_drop

			target_slot.item.state["amount"] = slot_amount - amount_to_drop
			if target_slot.item.state["amount"] <= 0:
				target_slot.clear_slot()

			if parent_node is StorageComponent:
				parent_node.storage_updated.emit()
			elif parent_node is Inventory:
				# ZABEZPIECZENIE: Jeśli wyrzuciliśmy 'Q' coś z plecaka/zbroi, wymuszamy restart pasywek
				if slot_idx <= -10:
					parent_node._recalculate_slots_size()
					parent_node.equipment_updated.emit()
				parent_node.inventory_updated.emit()

			_execute_drop_in_world(dropped_instance)

## Sprawdza, czy kursor znajduje się nad panelem obsługującym interakcje z ekwipunkiem.
func is_mouse_over_inventory_panels() -> bool:
	if not _is_initialized():
		return false

	var mouse_pos = _ui_owner.get_viewport().get_mouse_position()

	# 1. Sprawdzamy ramkę samego ekwipunku/skrzyni
	if _main_inventory_window and _main_inventory_window.visible:
		var panel = _main_inventory_window.get_node_or_null("PanelContainer")
		if panel and panel.get_global_rect().has_point(mouse_pos):
			return true

	# 2. Sprawdzamy ramkę panelu Craftingu
	if _crafting_ui and _crafting_ui.visible:
		var panel = _crafting_ui.get_node_or_null("BackgroundPanel")
		if panel and panel.get_global_rect().has_point(mouse_pos):
			return true

	return false

func _execute_drop_in_world(dropped_instance: ItemInstance) -> void:
	if dropped_instance == null:
		return

	var player = _ui_owner.get_tree().get_first_node_in_group("Player")
	if player and player.has_node("ItemThrowerComponent"):
		var thrower = player.get_node("ItemThrowerComponent")
		var aim_target = Vector2.ZERO
		if player.has_node("AimController") and player.get_node("AimController").aim_scanner:
			aim_target = player.get_node("AimController").aim_scanner.target_position
		thrower.handle_item_drop(player, dropped_instance, true, true, aim_target)
	else:
		if _player_inventory:
			_player_inventory.item_dropped.emit(dropped_instance, true)

func _is_initialized() -> bool:
	return (
		_ui_owner != null
		and is_instance_valid(_ui_owner)
		and _player_inventory != null
		and is_instance_valid(_player_inventory)
		and _slot_interactor != null
		and _cursor_item_rect != null
		and _cursor_amount_label != null
	)
