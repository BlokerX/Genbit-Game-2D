@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is ItemData

func _parse_begin(object: Object) -> void:
	var vbox = VBoxContainer.new()
	
	# --- 1. SEKCJA: GENERATORY (ID oraz Nazwa) ---
	var label_gen = Label.new()
	label_gen.text = "Narzędzia Automatyzacji:"
	label_gen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_gen)
	
	var hbox_generators = HBoxContainer.new()
	
	var btn_id = Button.new()
	btn_id.text = "Generuj ID"
	btn_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_id.pressed.connect(func():
		var file_name = object.resource_path.get_file().get_basename()
		object.item_id = StringName(file_name)
		object.emit_changed()
		print("Wtyczka: Zaktualizowano ID na -> ", object.item_id)
	)
	hbox_generators.add_child(btn_id)
	
	var btn_name = Button.new()
	btn_name.text = "Generuj Nazwę"
	btn_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_name.pressed.connect(func():
		var file_name = object.resource_path.get_file().get_basename()
		# Funkcja capitalize() zamienia "potion_liliput" na "Potion Liliput"
		object.item_name = file_name.capitalize()
		object.emit_changed()
		print("Wtyczka: Zaktualizowano Nazwę na -> ", object.item_name)
	)
	hbox_generators.add_child(btn_name)
	
	vbox.add_child(hbox_generators)
	vbox.add_child(HSeparator.new())
	
	# --- 2. SEKCJA: PRECYZYJNE SZABLONY KOMPONENTÓW ---
	var label_tpl = Label.new()
	label_tpl.text = "Precyzyjne Szablony:"
	label_tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_tpl)
	
	var hbox_templates = HBoxContainer.new()
	
	var opt = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# === LOGICZNE SORTOWANIE KATEGORIAMI ===
	
	# Baza i Pozyskiwanie
	opt.add_item("Zwykły Surowiec (Drewno / Ruda)")        # 0
	opt.add_item("Narzędzie (Kilof / Siekiera)")           # 1
	
	# Walka Wręcz
	opt.add_item("Broń Wręcz (Standard)")                  # 2
	opt.add_item("Broń Wręcz (Magiczna / Z ładunkami)")    # 3
	
	# Walka Dystansowa
	opt.add_item("Broń Palna (Wymaga Amunicji)")           # 4
	opt.add_item("Broń Dystansowa (Laser / Energia)")      # 5
	opt.add_item("Amunicja (Stackowalna)")                 # 6
	
	# Ubiór i Ekwipunek
	opt.add_item("Pancerz / Hełm / Pierścień")             # 7
	opt.add_item("Plecak (+5 Miejsc)")                     # 8
	
	# Użytkowe / Konsumpcyjne
	opt.add_item("Jedzenie (Stosy / Bezpieczne)")          # 9
	opt.add_item("Mikstura (Potężna / Krótki CD)")         # 10
	opt.add_item("Artefakt (Odnawialne ładunki)")          # 11
	
	# Konstrukcja i Inne
	opt.add_item("Budowla / Mebel (Stawialny)")            # 12
	opt.add_item("Przedmiot Fabularny (Quest Item)")       # 13

	hbox_templates.add_child(opt)
	
	var btn_template = Button.new()
	btn_template.text = "Dodaj Klocki"
	btn_template.pressed.connect(func():
		_apply_template(object, opt.selected)
	)
	hbox_templates.add_child(btn_template)
	
	vbox.add_child(hbox_templates)
	
	var bottom_sep = HSeparator.new()
	bottom_sep.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bottom_sep)
	
	add_custom_control(vbox)

## Funkcja wstrzykująca wybrane komponenty z inteligentnymi domyślnymi wartościami
func _apply_template(item: ItemData, template_idx: int) -> void:
	var new_components: Array[ItemComponent] = []
	if item.components != null:
		new_components.append_array(item.components)
		
	match template_idx:
		0: # Zwykły Surowiec
			var stack = StackComponent.new()
			stack.max_stack = 64
			new_components.append(stack)
			
		1: # Narzędzie
			var melee = MeleeWeaponComponent.new()
			melee.attack_data = AttackData.new()
			melee.attack_data.damage = 5 # Mniejsze obrażenia niż miecz
			new_components.append(melee)
			var dur = DurabilityComponent.new()
			dur.max_durability = 300 # Ogromna wytrzymałość do pracy
			new_components.append(dur)
			
		2: # Broń Wręcz (Standard)
			var melee = MeleeWeaponComponent.new()
			melee.attack_data = AttackData.new() 
			new_components.append(melee)
			var dur = DurabilityComponent.new()
			dur.max_durability = 100
			new_components.append(dur)
			
		3: # Broń Wręcz (Magiczna)
			var melee = MeleeWeaponComponent.new()
			melee.attack_data = AttackData.new()
			new_components.append(melee)
			var dur = DurabilityComponent.new()
			dur.max_durability = 50
			new_components.append(dur)
			var charges = ChargesComponent.new()
			charges.max_charges = 10
			new_components.append(charges)
			
		4: # Broń Palna
			var ranged = RangedWeaponComponent.new()
			ranged.uses_ammunition = true
			ranged.accepted_ammunition_type = RangedWeaponComponent.AmmoType.BULLET 
			ranged.magazine_capacity = 5
			# NOWOŚĆ: Automatycznie tworzymy statystyki broni z sensownym zasięgiem strzału!
			ranged.attack_data = AttackData.new()
			ranged.attack_data.damage = 0
			ranged.attack_data.max_range = 1500.0 
			new_components.append(ranged)
			var dur = DurabilityComponent.new()
			dur.max_durability = 200
			new_components.append(dur)
			
		5: # Broń Dystansowa (Laser)
			var ranged = RangedWeaponComponent.new()
			ranged.uses_ammunition = false
			# NOWOŚĆ: Tworzymy statystyki dla lasera i od razu podbijamy mu zasięg oraz obrażenia
			ranged.attack_data = AttackData.new()
			ranged.attack_data.damage = 25 
			ranged.attack_data.max_range = 2500.0 
			new_components.append(ranged)
			var dur = DurabilityComponent.new()
			dur.max_durability = 200
			new_components.append(dur)
			
		6: # Amunicja
			var ammo = AmmunitionComponent.new()
			ammo.ammunition_type = RangedWeaponComponent.AmmoType.BULLET
			ammo.damage = 15
			new_components.append(ammo)
			var stack = StackComponent.new()
			stack.max_stack = 100
			new_components.append(stack)
			
		7: # Pancerz
			var equip = EquippableComponent.new()
			equip.equip_slot_type = EquippableComponent.EquipSlot.CHEST
			new_components.append(equip)
			var dur = DurabilityComponent.new()
			dur.max_durability = 500
			new_components.append(dur)
			
		8: # Plecak
			var equip = EquippableComponent.new()
			equip.equip_slot_type = EquippableComponent.EquipSlot.BACKPACK
			new_components.append(equip)
			var backpack = BackpackComponent.new()
			backpack.extra_slots_count = 5 
			new_components.append(backpack)
			
		9: # Jedzenie (Rozdzielone - Duże stosy, długi cooldown jedzenia)
			var cons = ConsumableComponent.new()
			cons.use_cooldown = 1.5
			new_components.append(cons)
			var stack = StackComponent.new()
			stack.max_stack = 16
			new_components.append(stack)
			
		10: # Mikstura (Rozdzielone - Małe stosy, szybki ratunek w walce)
			var cons = ConsumableComponent.new()
			cons.use_cooldown = 0.5
			new_components.append(cons)
			var stack = StackComponent.new()
			stack.max_stack = 12
			new_components.append(stack)
			
		11: # Artefakt
			var cons = ConsumableComponent.new()
			new_components.append(cons)
			var charges = ChargesComponent.new()
			charges.max_charges = 3
			new_components.append(charges)
			
		12: # Budowla
			var place = PlaceableComponent.new()
			new_components.append(place)
			var stack = StackComponent.new()
			stack.max_stack = 1
			new_components.append(stack)
			
		13: # Przedmiot Fabularny
			var stack = StackComponent.new()
			stack.max_stack = 1 # Nie łączy się, nie zużywa.
			new_components.append(stack)
			
	item.components = new_components
	item.emit_changed()
	print("Wtyczka: Zaaplikowano zoptymalizowany szablon do: ", item.resource_path.get_file())
