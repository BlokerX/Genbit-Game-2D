extends Node

enum InfoMode { NONE, BASIC, ADVANCED }

const INPUT_TOGGLE_INFO = "ToggleInfoMode"

@export var player : PlayerCharacter
@export var slot_scene: PackedScene = preload("res://assets/scenes/inventory_slot.tscn")
@onready var hotbar_panel = $HotbarPanel # Używamy węzła zamiast stałej listy dzieci
@export var info_label: Label

var slots_ui: Array = []

## Zmienna przechowująca aktualny tryb wyświetlania. Domyślnie: Podstawowy.
var current_info_mode: InfoMode = InfoMode.BASIC

func _ready() -> void:
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_on_inventory_updated)
		_on_inventory_updated()

func _unhandled_input(event: InputEvent) -> void:
	# Przełącza tryb w pętli: BASIC (1) -> ADVANCED (2) -> NONE (0) -> BASIC (1)...
	if event.is_action_pressed(INPUT_TOGGLE_INFO): 
		current_info_mode = (current_info_mode + 1) % 3 as InfoMode
		update_info_panel() # Natychmiast odświeżamy wyświetlany tekst!

func _on_inventory_updated() -> void:
	if not player or not player.inventory: return
	
	# --- Bierzemy mniejszą wartość (albo pełny ekwipunek, albo limit Hotbaru) ---
	var displayed_slots_count = min(player.inventory.slots.size(), player.inventory.hotbar_limit)
	
	# Jeśli liczba slotów w UI się nie zgadza z wyświetlaną, przebudowujemy pasek Hotbar!
	if slots_ui.size() != displayed_slots_count:
		for child in hotbar_panel.get_children():
			child.queue_free()
		slots_ui.clear()
		
		# Generujemy tylko tyle slotów, na ile pozwala limit
		for i in range(displayed_slots_count):
			var slot_ui = slot_scene.instantiate()
			hotbar_panel.add_child(slot_ui)
			slot_ui.setup_as_player_slot(i, player.inventory)
			slots_ui.append(slot_ui)
			
	# Aktualizujemy grafiki na bieżących slotach
	for i in range(displayed_slots_count):
		var slot_data = player.inventory.slots[i]
		if slots_ui[i].has_method("update_slot"):
			slots_ui[i].update_slot(slot_data)
		
		var is_selected = (i == player.inventory.current_slot_index)
		if slots_ui[i].has_method("set_highlight"):
			slots_ui[i].set_highlight(is_selected)

	update_info_panel()

func update_info_panel() -> void:
	if info_label == null: return
	
	var slot = player.inventory.get_current_slot()
	
	# TARCZA OPTYMALIZACYJNA: 
	# Jeśli tryb to NONE (brak wyświetlania) LUB slot jest pusty - od razu chowamy UI i przerywamy skrypt.
	if current_info_mode == InfoMode.NONE or slot == null or slot.is_empty():
		info_label.get_parent().hide()
		return
		
	var item = slot.item
	var text = ""
	
	# Flaga pomocnicza, żeby nie pisać długiego warunku za każdym razem
	var is_advanced = (current_info_mode == InfoMode.ADVANCED)
	
	# 1. NAGŁÓWEK
	if is_advanced:
		text += "[ TRYB ZAAWANSOWANY ]\n"
		text += "Nazwa: " + item.data.item_name + "\n"
		text += "ID Systemowe: " + str(item.data.item_id) + "\n"
		if item.data.tags.size() > 0:
			text += "Tagi: " + str(item.data.tags) + "\n"
	else:
		text += item.data.item_name + "\n"
	
	text += "------------------------\n"
	
	# 2. KOMPONENTY
	if item.data.components != null:
		for comp in item.data.components:
			
			# --- STACK ---
			if comp is StackComponent:
				if is_advanced:
					text += "Ilość: " + str(item.state.get("amount", 1)) + " / " + str(comp.max_stack) + "\n"
				else:
					if comp.max_stack > 1:
						text += "Ilość: " + str(item.state.get("amount", 1)) + "\n"
				
			# --- DURABILITY ---
			elif comp is DurabilityComponent:
				var cur_dur = item.state.get("durability", comp.max_durability)
				if is_advanced:
					text += "Wytrzymałość: " + str(cur_dur) + " / " + str(comp.max_durability) + " HP\n"
				else:
					var pct = int((float(cur_dur) / float(comp.max_durability)) * 100)
					text += "Stan Przedmiotu: " + str(pct) + "%\n"
					
			# --- MELEE WEAPON ---
			elif comp is MeleeWeaponComponent:
				if comp.attack_data != null:
					text += "Obrażenia: " + str(comp.attack_data.damage) + "\n"
					if comp.attack_data.critical_rate > 0.0:
						text += "Szansa na Kryta: " + str(comp.attack_data.critical_rate * 100.0) + "%\n"
						
					if is_advanced:
						text += "Zasięg Ataku: " + str(comp.attack_data.max_range) + "\n"
						text += "Szybkość (Cooldown): " + str(comp.use_cooldown) + "s\n"
						if comp.attack_data.critical_damage > 0:
							text += "Moc Krytyka: +" + str(comp.attack_data.critical_damage) + " DMG\n"
						if comp.attack_data.stun_time > 0.0:
							text += "Ogłuszenie: " + str(comp.attack_data.stun_time) + "s\n"
						
			# --- RANGED WEAPON ---
			elif comp is RangedWeaponComponent:
				if comp.attack_data != null:
					if is_advanced:
						text += "Obrażenia (Baza): " + str(comp.attack_data.damage) + "\n"
						text += "Zasięg Celowania: " + str(comp.attack_data.max_range) + "\n"
						text += "Szybkość (Cooldown): " + str(comp.use_cooldown) + "s\n"
						text += "Przeładowanie: " + str(comp.reload_time) + "s\n"
						text += "Szybkość Pocisku: " + str(comp.projectile_speed) + "\n"
						if comp.attack_data.critical_rate > 0.0:
							text += "Szansa na Kryta: " + str(comp.attack_data.critical_rate * 100.0) + "%\n"
					else:
						if comp.attack_data.damage > 0:
							text += "Obrażenia (Baza): " + str(comp.attack_data.damage) + "\n"
						text += "Zasięg Strzału: " + str(comp.attack_data.max_range) + "\n"
				
				if comp.weapon_effects.size() > 0:
					if is_advanced:
						text += "Efekty Nakładane (" + str(comp.weapon_effects.size()) + "):\n"
						for effect in comp.weapon_effects:
							if effect != null:
								text += "  - " + effect.effect_name + " (" + str(effect.duration) + "s)\n"
					else:
						text += "Statusy Specjalne: Tak\n"
							
				if comp.uses_ammunition:
					text += "Amunicja: " + RangedWeaponComponent.AmmoType.keys()[comp.accepted_ammunition_type] + "\n"
					text += "Magazynek: " + str(item.state.get("ammo_count", 0)) + " / " + str(comp.magazine_capacity) + "\n"
				else:
					text += "Zasilanie: Nieskończone\n"
					
			# --- AMMUNITION ---
			elif comp is AmmunitionComponent:
				text += "Typ Naboju: " + RangedWeaponComponent.AmmoType.keys()[comp.ammunition_type] + "\n"
				text += "Moc Pocisku: +" + str(comp.damage) + "\n"
				if is_advanced:
					text += "Mnożnik Szybkości: x" + str(comp.speed_multiplier) + "\n"
					if comp.effects.size() > 0:
						text += "Efekty Naboju: " + str(comp.effects.size()) + "\n"
				
			# --- EQUIPPABLE ---
			elif comp is EquippableComponent:
				text += "Zakładany na: " + EquippableComponent.EquipSlot.keys()[comp.equip_slot_type] + "\n"
				if is_advanced and comp.passive_buffs.size() > 0:
					text += "Ilość Buffów Pasywnych: " + str(comp.passive_buffs.size()) + "\n"
					
			# --- CONSUMABLE ---
			elif comp is ConsumableComponent:
				if is_advanced:
					text += "Efekty Konsumpcji (" + str(comp.effects.size()) + "):\n"
					text += "Szybkość użycia: " + str(comp.use_cooldown) + "s\n"
					for effect in comp.effects:
						if effect != null:
							text += "  - " + effect.effect_name + " (" + str(effect.duration) + "s)\n"
				else:
					text += "Posiada Efekty Specjalne: Tak\n"
				
				if comp.conditions.size() > 0:
					text += "Wymagania Użycia:\n"
					for cond in comp.conditions:
						if cond != null:
							if cond is HealthNotFullCondition:
								text += "  - Tylko gdy ranny\n"
							else:
								text += "  - Zablokowane warunkiem\n"
			
			# --- PLACEABLE ---
			elif comp is PlaceableComponent:
				if is_advanced:
					text += "Obiekt Konstrukcyjny\n"
					if comp.scene_path != null and comp.scene_path != "":
						text += "Model: " + comp.scene_path.get_file() + "\n"

	# 3. OPIS PRZEDMIOTU
	if item.data.item_description != "":
		text += "------------------------\n"
		text += item.data.item_description
		
	info_label.text = text
	info_label.get_parent().show()
