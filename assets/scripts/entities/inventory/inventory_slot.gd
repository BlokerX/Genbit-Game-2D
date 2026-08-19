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

## Pasek wytrzymałości
@onready var durability_bar: ProgressBar = $DurabilityBar

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
		
		# --- 1. WYŚWIETLANIE ILOŚCI (Zaktualizowane na słownik state) ---
		if slot.item.state.has("amount") and slot.item.state["amount"] > 1:
			amount_label.text = str(slot.item.state["amount"])
			amount_label.show()
		else:
			amount_label.hide()
			
		# --- 2. SYSTEM PASKA WYTRZYMAŁOŚCI (Zaktualizowany na Komponenty) ---
		if slot.item.state.has("durability"):
			var max_dur = 1
			# Szukamy komponentu, żeby dowiedzieć się, z jakiej wartości liczyć procenty
			for comp in slot.item.data.components:
				if comp is DurabilityComponent:
					max_dur = comp.max_durability
					break
			
			durability_bar.show()
			durability_bar.max_value = max_dur
			durability_bar.value = slot.item.state["durability"]
			
			# Obliczamy procent zużycia (od 0.0 do 1.0)
			var percentage = float(slot.item.state["durability"]) / float(max_dur)
			var bar_color = Color.GREEN
			
			if percentage <= 0.2:
				bar_color = Color.RED
			elif percentage <= 0.5:
				bar_color = Color.ORANGE
			elif percentage <= 0.8:
				bar_color = Color.GREEN_YELLOW
				
			var fill_stylebox = StyleBoxFlat.new()
			fill_stylebox.bg_color = bar_color
			durability_bar.add_theme_stylebox_override("fill", fill_stylebox)
			
			var bg_stylebox = StyleBoxFlat.new()
			bg_stylebox.bg_color = Color(0, 0, 0, 0.8)
			durability_bar.add_theme_stylebox_override("background", bg_stylebox)
		else:
			durability_bar.hide()
			
		# --- 3. GENEROWANIE INFORMACJI W TOOLTIPIE (Odczyt z Komponentów) ---
		if show_tooltip:
			var item_data = slot.item.data
			var tooltip_info = item_data.item_name + "\nID: " + str(item_data.item_id) + "\n"
			
			if item_data.item_description != "":
				tooltip_info += item_data.item_description + "\n\n"
				
			# Pytamy klocki (komponenty) o ich dane do tooltipa!
			if item_data.components != null:
				for comp in item_data.components:
					if comp is DurabilityComponent:
						tooltip_info += "Wytrzymałość: " + str(slot.item.state.get("durability", comp.max_durability)) + " / " + str(comp.max_durability) + "\n"
					elif comp is MeleeWeaponComponent:
						tooltip_info += "Obrażenia: " + str(comp.attack_data.damage) + "\n"
						if comp.attack_data.critical_rate > 0.0:
							tooltip_info += "Szansa na Kryta: " + str(comp.attack_data.critical_rate * 100.0) + "%\n"
					elif comp is RangedWeaponComponent:
						if comp.attack_data != null:
							tooltip_info += "Obrażenia Bazowe: " + str(comp.attack_data.damage) + "\n"
							tooltip_info += "Zasięg Celowania: " + str(comp.attack_data.max_range) + "\n"
							if comp.attack_data.critical_rate > 0.0:
								tooltip_info += "Szansa na Kryta: " + str(comp.attack_data.critical_rate * 100.0) + "%\n"
						
						if comp.weapon_effects.size() > 0:
							tooltip_info += "Efekty Broni: " + str(comp.weapon_effects.size()) + "\n"
							for effect in comp.weapon_effects:
								if effect != null:
									tooltip_info += "- " + effect.effect_name + "\n"
									
						if comp.uses_ammunition:
							tooltip_info += "Typ Amunicji: " + RangedWeaponComponent.AmmoType.keys()[comp.accepted_ammunition_type] + "\n"
							tooltip_info += "Magazynek: " + str(slot.item.state.get("ammo_count", 0)) + " / " + str(comp.magazine_capacity) + "\n"
						else:
							tooltip_info += "Zasilanie: Nieskończone (Brak amunicji)\n"
						
					elif comp is AmmunitionComponent:
						tooltip_info += "Typ Naboju: " + RangedWeaponComponent.AmmoType.keys()[comp.ammunition_type] + "\n"
						tooltip_info += "Obrażenia Pocisku: " + str(comp.damage) + "\n"
					elif comp is EquippableComponent:
						tooltip_info += "Zakładany na: " + EquippableComponent.EquipSlot.keys()[comp.equip_slot_type] + "\n"
					elif comp is ConsumableComponent:
						tooltip_info += "Efekty po użyciu: " + str(comp.effects.size()) + "\n"
						for effect in comp.effects:
							if effect != null:
								tooltip_info += "- " + effect.effect_name + "\n"
							
			self.tooltip_text = tooltip_info
		else:
			self.tooltip_text = ""

	else:
		# Pusty slot - ukrywamy wszystko
		icon_rect.texture = null
		icon_rect.hide()
		amount_label.hide()
		durability_bar.hide()
		self.tooltip_text = ""

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
