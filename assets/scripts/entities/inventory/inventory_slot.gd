# inventory_slot.gd
extends TextureRect
class_name InventorySlot

@export_group("Slot Textures")
## Tekstura zwykłego, niewybranego slotu
@export var texture_normal: Texture2D
## Tekstura aktywnego (wybranego) slotu
@export var texture_highlighted: Texture2D

@export_group("Ustawienia")
## Czy ten slot ma wyświetlać dymek z informacjami po najechaniu myszką?
@export var show_tooltip: bool = true

@onready var icon_rect: TextureRect = $Item
# Pobieramy nasz nowy węzeł z cyferką
@onready var amount_label: Label = $AmountLabel

var is_storage_slot: bool = false
var slot_index: int = -1
var parent_reference: Node = null 

func setup_as_storage_slot(index: int, storage_ref: Node) -> void:
	is_storage_slot = true
	slot_index = index
	parent_reference = storage_ref

func setup_as_player_slot(index: int, inventory_ref: Node) -> void:
	is_storage_slot = false
	slot_index = index
	parent_reference = inventory_ref

func setup_as_backpack_slot(inventory_ref: Node) -> void:
	is_storage_slot = false
	slot_index = -2 # Celowo ujemny, aby odróżnić go od zwykłych slotów (0, 1, 2...)
	parent_reference = inventory_ref

func update_slot(slot: SlotData) -> void:
	if slot and not slot.is_empty():
		icon_rect.texture = slot.item.data.item_icon
		icon_rect.show()
		
		# Wyświetlanie ilości (stack)
		if slot.item.amount > 1:
			amount_label.text = str(slot.item.amount)
			amount_label.show()
		else:
			amount_label.hide()
			
		# --- GENEROWANIE INFORMACJI W TOOLTIPIE ---
		if show_tooltip:
			var item_data = slot.item.data
			var tooltip_info = item_data.item_name + "\n" # Nazwa zawsze na samej górze
			
			# Jeśli przedmiot ma opis, dodajemy go
			if item_data.item_description != "":
				tooltip_info += item_data.item_description + "\n\n"
				
			# Jeśli przedmiot psuje się, pokazujemy jego wytrzymałość
			if item_data.max_durable > 0:
				tooltip_info += "Wytrzymałość: " + str(slot.item.durability) + " / " + str(item_data.max_durable) + "\n"
				
			# Jeśli przedmiot to broń (sprawdzamy czy dziedziczy po ItemWeapon)
			if item_data is ItemWeapon:
				tooltip_info += "Obrażenia: " + str(item_data.attack_data.damage) + "\n"
				if item_data.attack_data.critical_rate > 0.0:
					tooltip_info += "Szansa na Kryta: " + str(item_data.attack_data.critical_rate * 100.0) + "%\n"
				if item_data.attack_data.stun_time > 0.0:
					tooltip_info += "Czas Ogłuszenia: " + str(item_data.attack_data.stun_time) + "s\n"
			
			# Jeśli to mikstura/jedzenie (EatableItem) - opcjonalnie
			elif item_data is UseableItem and item_data.effects.size() > 0:
				tooltip_info += "Efekty po użyciu: " + str(item_data.effects.size()) + "\n"

			# Przypisujemy zbudowany tekst do wbudowanego dymka
			self.tooltip_text = tooltip_info
		else:
			# Jeśli opcja show_tooltip jest wyłączona w edytorze
			self.tooltip_text = ""

	else:
		# Pusty slot - ukrywamy wszystko
		icon_rect.texture = null
		icon_rect.hide()
		amount_label.hide()
		self.tooltip_text = "" # Czyścimy dymek dla pustego slota!

# Funkcja zmieniająca teksturę w zależności od stanu
func set_highlight(is_active: bool) -> void:
	if is_active:
		# Jeśli slot jest wybrany, dajemy podświetloną teksturę
		texture = texture_highlighted
	else:
		# Jeśli nie jest wybrany, wracamy do zwykłej tekstury
		texture = texture_normal

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		
		# Szybki transfer (Shift + Lewy Klik)
		if Input.is_key_pressed(KEY_SHIFT) and event.button_index == MOUSE_BUTTON_LEFT:
			if icon_rect.texture != null:
				EventBus.slot_clicked.emit(parent_reference, slot_index, -1)
			accept_event()
			return
			
		# Normalny Lewy lub Prawy Klik
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.slot_clicked.emit(parent_reference, slot_index, event.button_index)
			accept_event()
