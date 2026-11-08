extends Node
class_name EquipmentInventoryUI
## Kontroler widoku slotów wyposażenia (zbroja, akcesoria, amulet, plecak).

@export_category("Widok ekwipunku")
@export var equipment_window: Control
@export var equipment_collapsible: Control
@export var toggle_equipment_button: Button

@export_category("Sloty wyposażenia")
@export var head_slot: InventorySlot
@export var chest_slot: InventorySlot
@export var legs_slot: InventorySlot
@export var boots_slot: InventorySlot
@export var accessory_slot: InventorySlot
@export var amulet_slot: InventorySlot
@export var backpack_slot: InventorySlot

var _inventory: Inventory
var _slot_views: Dictionary = {}
var _slot_names: Dictionary = {
	EquippableComponent.EquipSlot.HEAD: "Głowa",
	EquippableComponent.EquipSlot.CHEST: "Tors",
	EquippableComponent.EquipSlot.LEGS: "Spodnie",
	EquippableComponent.EquipSlot.BOOTS: "Buty",
	EquippableComponent.EquipSlot.ACCESSORY: "Akcesorium",
	EquippableComponent.EquipSlot.AMULET: "Amulet",
	EquippableComponent.EquipSlot.BACKPACK: "Plecak"
}

func _ready() -> void:
	if toggle_equipment_button:
		toggle_equipment_button.pressed.connect(_toggle_collapsible)
	set_visible(false)

func initialize(inventory: Inventory) -> void:
	if inventory == null:
		push_error("EquipmentInventoryUI wymaga ekwipunku gracza.")
		return

	_inventory = inventory
	_slot_views = {
		EquippableComponent.EquipSlot.HEAD: head_slot,
		EquippableComponent.EquipSlot.CHEST: chest_slot,
		EquippableComponent.EquipSlot.LEGS: legs_slot,
		EquippableComponent.EquipSlot.BOOTS: boots_slot,
		EquippableComponent.EquipSlot.ACCESSORY: accessory_slot,
		EquippableComponent.EquipSlot.AMULET: amulet_slot,
		EquippableComponent.EquipSlot.BACKPACK: backpack_slot
	}

	for slot_type in _slot_views:
		var slot_view: InventorySlot = _slot_views[slot_type]
		if slot_view != null:
			slot_view.setup_as_equipment_slot(slot_type, _inventory)

	if not _inventory.inventory_updated.is_connected(_refresh_equipment_slots):
		_inventory.inventory_updated.connect(_refresh_equipment_slots)

	_refresh_equipment_slots()

func set_visible(is_visible: bool) -> void:
	if equipment_window:
		equipment_window.visible = is_visible

func _toggle_collapsible() -> void:
	if not equipment_collapsible:
		return
	equipment_collapsible.visible = not equipment_collapsible.visible
	if toggle_equipment_button:
		toggle_equipment_button.text = (
			"ZBROJA I AKCESORIA <<"
			if equipment_collapsible.visible
			else "ZBROJA I AKCESORIA >>"
		)

func _refresh_equipment_slots() -> void:
	if _inventory == null:
		return

	for slot_type in _slot_views:
		var slot_view: InventorySlot = _slot_views[slot_type]
		if slot_view == null:
			continue

		var slot_data: SlotData = _inventory.equipment_slots[slot_type]
		slot_view.update_slot(slot_data)

		var background_label: Control = slot_view.get_node_or_null("BgLabel") as Control
		if background_label != null:
			# Gwarantujemy, że napis w tle slotu nigdy nie zablokuje najechania myszką (Tooltipa)!
			background_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var slot_label_name: String = _slot_names.get(slot_type, "Wyposażenie")
		if slot_data.is_empty():
			slot_view.tooltip_text = "Slot: " + slot_label_name
			if background_label != null:
				background_label.show()
		else:
			# NAPRAWA KRYTYCZNA: Zachowujemy opis przedmiotu wygenerowany przez slot_view.update_slot(slot_data)
			# i dodajemy na górze czytelny nagłówek nazwy slotu!
			if slot_view.show_tooltip and slot_view.tooltip_text != "":
				slot_view.tooltip_text = "[Slot: " + slot_label_name + "]\n" + slot_view.tooltip_text
			if background_label != null:
				background_label.hide()
