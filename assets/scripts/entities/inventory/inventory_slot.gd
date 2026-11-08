# inventory_slot.gd
extends TextureRect
class_name InventorySlot

# --- STAŁE KONFIGURACYJNE I WIZUALNE (Brak magicznych liczb) ---
const DEFAULT_TOOLTIP_MARGIN_PX: float = 10.0
const DEFAULT_TOOLTIP_BG_COLOR := Color(0.15, 0.15, 0.15, 1.0)
const DURABILITY_BAR_BG_COLOR := Color(0.0, 0.0, 0.0, 0.8)

const DURABILITY_CRITICAL_RATIO: float = 0.2
const DURABILITY_LOW_RATIO: float = 0.5
const DURABILITY_GOOD_RATIO: float = 0.8

const EQUIPMENT_SLOT_INDEX_OFFSET: int = -10
const QUICK_TRANSFER_BUTTON_CODE: int = -1
const MIN_STACK_DISPLAY_COUNT: int = 1

@export_group("Slot Textures")
## Tekstura zwykłego, niewybranego slotu
@export var texture_normal: Texture2D
## Tekstura aktywnego (wybranego) slotu
@export var texture_highlighted: Texture2D

@export_group("Ustawienia")
## Czy ten slot ma wyświetlać dymek z informacjami po najechaniu myszką?
@export var show_tooltip: bool = true
## Czy w dymku tooltipa ma być wyświetlane techniczne ID przedmiotu (np. ID: sword_iron)?
@export var show_item_id_in_tooltip: bool = true

@onready var icon_rect: TextureRect = $Item
## Węzeł tekstowy z liczebnością stosu
@onready var amount_label: Label = $AmountLabel
## Pasek wytrzymałości przedmiotu
@onready var durability_bar: ProgressBar = $DurabilityBar

var is_storage_slot: bool = false
var slot_index: int = -1
var parent_reference: Node = null 

@export_group("Tooltip Style")
## Styl wyglądu dymka. Stwórz tu nowy StyleBoxFlat, aby go edytować!
@export var custom_tooltip_style: StyleBoxFlat

func _ready() -> void:
	# Upewniamy się, że sam slot przechwytuje kursor myszy dla dymków (Tooltip) i kliknięć,
	# a jego wewnętrzne dzieci wizualne (ikona, licznik, pasek, BgLabel) przepuszczają myszkę!
	mouse_filter = Control.MOUSE_FILTER_STOP
	if icon_rect != null:
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if amount_label != null:
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if durability_bar != null:
		durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_label: Control = get_node_or_null("BgLabel") as Control
	if bg_label != null:
		bg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tooltip_style: StyleBoxFlat

	if custom_tooltip_style != null:
		# 1. Opcja: Używamy stylu z Inspektora (jeśli został przypisany)
		tooltip_style = custom_tooltip_style
	else:
		# 2. Opcja: Brak stylu w Inspektorze - tworzymy bezpieczny, domyślny styl
		tooltip_style = StyleBoxFlat.new()
		tooltip_style.bg_color = DEFAULT_TOOLTIP_BG_COLOR
		tooltip_style.content_margin_left = DEFAULT_TOOLTIP_MARGIN_PX
		tooltip_style.content_margin_right = DEFAULT_TOOLTIP_MARGIN_PX
		tooltip_style.content_margin_top = DEFAULT_TOOLTIP_MARGIN_PX
		tooltip_style.content_margin_bottom = DEFAULT_TOOLTIP_MARGIN_PX
		# Wyłączenie wygładzania dla pixel-artowego wyglądu ramki
		tooltip_style.anti_aliasing = false

	# Przypisujemy wybrany styl (z Inspektora lub domyślny) do slota
	var custom_theme: Theme = Theme.new()
	custom_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	self.theme = custom_theme

func setup_as_storage_slot(index: int, storage_ref: Node) -> void:
	is_storage_slot = true
	slot_index = index
	parent_reference = storage_ref

func setup_as_player_slot(index: int, inventory_ref: Node) -> void:
	is_storage_slot = false
	slot_index = index
	parent_reference = inventory_ref

func setup_as_equipment_slot(equip_slot_type: int, inventory_ref: Node) -> void:
	is_storage_slot = false
	# Mapujemy enum pancerza na ujemny indeks (np. 1 -> -11), by odciąć go od zwykłego ekwipunku
	slot_index = EQUIPMENT_SLOT_INDEX_OFFSET - equip_slot_type
	parent_reference = inventory_ref

func update_slot(slot: SlotData) -> void:
	if slot != null and not slot.is_empty():
		var item_instance: ItemInstance = slot.item
		var item_data: ItemData = item_instance.data

		icon_rect.texture = item_data.item_icon
		icon_rect.show()

		# --- 1. WYŚWIETLANIE ILOŚCI (Słownik state) ---
		var stack_amount: int = item_instance.state.get("amount", MIN_STACK_DISPLAY_COUNT)
		if stack_amount > MIN_STACK_DISPLAY_COUNT:
			amount_label.text = str(stack_amount)
			amount_label.show()
		else:
			amount_label.hide()

		# --- 2. SYSTEM PASKA WYTRZYMAŁOŚCI ---
		if item_instance.state.has("durability"):
			var max_dur: int = maxi(1, item_instance.get_max_durability())
			var cur_dur: int = item_instance.state["durability"]

			durability_bar.show()
			durability_bar.max_value = max_dur
			durability_bar.value = cur_dur

			# Obliczamy procent zużycia (od 0.0 do 1.0)
			var percentage: float = float(cur_dur) / float(max_dur)
			var bar_color: Color = Color.GREEN

			if percentage <= DURABILITY_CRITICAL_RATIO:
				bar_color = Color.RED
			elif percentage <= DURABILITY_LOW_RATIO:
				bar_color = Color.ORANGE
			elif percentage <= DURABILITY_GOOD_RATIO:
				bar_color = Color.GREEN_YELLOW

			var fill_stylebox: StyleBoxFlat = StyleBoxFlat.new()
			fill_stylebox.bg_color = bar_color
			durability_bar.add_theme_stylebox_override("fill", fill_stylebox)

			var bg_stylebox: StyleBoxFlat = StyleBoxFlat.new()
			bg_stylebox.bg_color = DURABILITY_BAR_BG_COLOR
			durability_bar.add_theme_stylebox_override("background", bg_stylebox)
		else:
			durability_bar.hide()

		# --- 3. GENEROWANIE INFORMACJI W TOOLTIPIE (Zasada Open/Closed - OCP!) ---
		if show_tooltip:
			var tooltip_info: String = item_data.item_name + "\n"
			if show_item_id_in_tooltip:
				tooltip_info += "ID: " + str(item_data.item_id) + "\n"
			if item_data.item_description != "":
				tooltip_info += item_data.item_description + "\n\n"

			# Każdy komponent sam formatuje swoje dane dla tooltipa (brak drabin if/elif w UI!)
			if item_data.components != null:
				for comp in item_data.components:
					if comp != null:
						tooltip_info += comp.get_tooltip_info(item_instance)

			self.tooltip_text = tooltip_info.strip_edges()
		else:
			self.tooltip_text = ""

	else:
		# Pusty slot - ukrywamy wszystko
		icon_rect.texture = null
		icon_rect.hide()
		amount_label.hide()
		durability_bar.hide()
		self.tooltip_text = ""

# Funkcja zmieniająca teksturę w zależności od stanu zaznaczenia na Hotbarze
func set_highlight(is_active: bool) -> void:
	if is_active:
		texture = texture_highlighted
	else:
		texture = texture_normal

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Szybki transfer / szybkie założenie (Shift + Lewy Klik)
		if Input.is_key_pressed(KEY_SHIFT) and event.button_index == MOUSE_BUTTON_LEFT:
			if icon_rect.texture != null:
				EventBus.slot_clicked.emit(parent_reference, slot_index, QUICK_TRANSFER_BUTTON_CODE)
			accept_event()
			return

		# Normalny Lewy lub Prawy Klik
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.slot_clicked.emit(parent_reference, slot_index, event.button_index)
			accept_event()
