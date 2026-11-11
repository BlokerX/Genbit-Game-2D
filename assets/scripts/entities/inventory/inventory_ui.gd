extends Node
## Kontroler widoku paska szybkiego dostępu (Hotbar) oraz panelu informacji o trzymanym przedmiocie.

enum InfoMode { NONE, BASIC, ADVANCED }

const INPUT_TOGGLE_INFO: String = "ToggleInfoMode"
const INFO_MODES_COUNT: int = 3
const SECTION_SEPARATOR_LINE: String = "------------------------\n"

@export var player : PlayerCharacter
@export var slot_scene: PackedScene = preload("res://assets/scenes/gui/inventory_slot.tscn")

@onready var hotbar_panel: Node = $HotbarPanel
@export var info_label: Label

var slots_ui: Array = []

## Zmienna przechowująca aktualny tryb wyświetlania. Domyślnie: Podstawowy.
var current_info_mode: InfoMode = InfoMode.BASIC

func _ready() -> void:
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_on_inventory_updated)
		_on_inventory_updated()

func _unhandled_input(event: InputEvent) -> void:
	# --- TARCZA DIALOGOWA ---
	if DialogueManager.is_active:
		return

	# Przełącza tryb w pętli: BASIC (1) -> ADVANCED (2) -> NONE (0) -> BASIC (1)...
	if event.is_action_pressed(INPUT_TOGGLE_INFO): 
		current_info_mode = ((int(current_info_mode) + 1) % INFO_MODES_COUNT) as InfoMode
		update_info_panel() # Natychmiast odświeżamy wyświetlany tekst!

func _on_inventory_updated() -> void:
	if not player or not player.inventory:
		return

	# Bierzemy mniejszą wartość (albo pełny ekwipunek, albo limit Hotbaru)
	var displayed_slots_count: int = mini(player.inventory.slots.size(), player.inventory.hotbar_limit)

	# Jeśli liczba slotów w UI się nie zgadza z wyświetlaną, przebudowujemy pasek Hotbar!
	if slots_ui.size() != displayed_slots_count:
		for child in hotbar_panel.get_children():
			child.queue_free()
		slots_ui.clear()

		# Generujemy tylko tyle slotów, na ile pozwala limit
		for i in range(displayed_slots_count):
			var slot_ui: InventorySlot = slot_scene.instantiate() as InventorySlot
			hotbar_panel.add_child(slot_ui)
			slot_ui.setup_as_player_slot(i, player.inventory)
			slots_ui.append(slot_ui)

	# Aktualizujemy grafiki na bieżących slotach
	for i in range(displayed_slots_count):
		var slot_data: SlotData = player.inventory.slots[i]
		if slots_ui[i].has_method("update_slot"):
			slots_ui[i].update_slot(slot_data)

		var is_selected: bool = (i == player.inventory.current_slot_index)
		if slots_ui[i].has_method("set_highlight"):
			slots_ui[i].set_highlight(is_selected)

	update_info_panel()

func update_info_panel() -> void:
	if info_label == null or player == null or player.inventory == null:
		return

	var slot: SlotData = player.inventory.get_current_slot()

	# TARCZA OPTYMALIZACYJNA I USTAWIEŃ GUI:
	# Jeśli gracz wyłączył panel informacji w ustawieniach (GlobalSettings.show_item_info == false),
	# lub tryb to NONE, lub slot jest pusty - chowamy kontener i przerywamy funkcję.
	if (
		not GlobalSettings.show_item_info
		or current_info_mode == InfoMode.NONE
		or slot == null
		or slot.is_empty()
	):
		info_label.get_parent().hide()
		return

	var item: ItemInstance = slot.item
	var text: String = ""
	var is_advanced: bool = (current_info_mode == InfoMode.ADVANCED)

	# 1. NAGŁÓWEK
	if is_advanced:
		text += "[ TRYB ZAAWANSOWANY ]\n"
		text += "Nazwa: " + item.data.item_name + "\n"
		text += "ID Systemowe: " + str(item.data.item_id) + "\n"
		if item.data.tags.size() > 0:
			text += "Tagi: " + str(item.data.tags) + "\n"
	else:
		text += item.data.item_name + "\n"

	text += SECTION_SEPARATOR_LINE

	# 2. KOMPONENTY (Zasada Open/Closed - OCP: każdy komponent sam buduje swój opis!)
	if item.data.components != null:
		for comp in item.data.components:
			if comp != null:
				text += comp.get_hud_info(item, is_advanced)

	# 3. OPIS PRZEDMIOTU
	if item.data.item_description != "":
		text += SECTION_SEPARATOR_LINE
		text += item.data.item_description

	info_label.text = text.strip_edges()
	info_label.get_parent().show()
