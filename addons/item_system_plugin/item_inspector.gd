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
	
	opt.add_item("Broń Wręcz (Standard)")               # 0
	opt.add_item("Broń Wręcz (Magiczna/Z efektami)")    # 1
	opt.add_item("Broń Palna (Wymaga Amunicji)")        # 2
	opt.add_item("Amunicja (Stackowalna)")              # 3
	opt.add_item("Mikstura / Jedzenie (Jednorazowe)")   # 4
	opt.add_item("Artefakt (Odłnawialne ładunki)")      # 5
	opt.add_item("Pancerz / Hełm / Pierścień")          # 6
	opt.add_item("Plecak")                              # 7
	opt.add_item("Budowla / Mebel (Stawialny)")         # 8
	opt.add_item("Zwykły Surowiec (Drewno/Złoto)")      # 9
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
		0: # Broń Wręcz (Standard)
			var melee = MeleeWeaponComponent.new()
			melee.attack_data = AttackData.new() # Automatycznie tworzy zagnieżdżony zasób obrażeń!
			new_components.append(melee)
			var dur = DurabilityComponent.new()
			dur.max_durability = 100
			new_components.append(dur)
			
		1: # Broń Wręcz (Magiczna)
			var melee = MeleeWeaponComponent.new()
			melee.attack_data = AttackData.new()
			new_components.append(melee)
			var dur = DurabilityComponent.new()
			dur.max_durability = 50
			new_components.append(dur)
			var charges = ChargesComponent.new()
			charges.max_charges = 10
			new_components.append(charges)
			
		2: # Broń Palna
			var ranged = RangedWeaponComponent.new()
			ranged.uses_ammunition = true
			ranged.accepted_ammunition_type = RangedWeaponComponent.AmmoType.BULLET # Domyślnie na kule
			ranged.magazine_capacity = 12
			new_components.append(ranged)
			var dur = DurabilityComponent.new()
			dur.max_durability = 200
			new_components.append(dur)
			
		3: # Amunicja
			var ammo = AmmunitionComponent.new()
			ammo.ammunition_type = RangedWeaponComponent.AmmoType.BULLET
			ammo.damage = 15
			new_components.append(ammo)
			var stack = StackComponent.new()
			stack.max_stack = 100
			new_components.append(stack)
			
		4: # Mikstura
			var cons = ConsumableComponent.new()
			cons.use_cooldown = 1.0
			new_components.append(cons)
			var stack = StackComponent.new()
			stack.max_stack = 12
			new_components.append(stack)
			
		5: # Artefakt
			var cons = ConsumableComponent.new()
			new_components.append(cons)
			var charges = ChargesComponent.new()
			charges.max_charges = 3
			new_components.append(charges)
			
		6: # Pancerz
			var equip = EquippableComponent.new()
			equip.equip_slot_type = EquippableComponent.EquipSlot.CHEST # Domyślnie pancerz na klatkę
			new_components.append(equip)
			var dur = DurabilityComponent.new()
			dur.max_durability = 500
			new_components.append(dur)
			
		7: # Plecak
			var equip = EquippableComponent.new()
			equip.equip_slot_type = EquippableComponent.EquipSlot.BACKPACK # Inteligentne ustawienie slota!
			new_components.append(equip)
			var backpack = BackpackComponent.new()
			backpack.extra_slots_count = 1 # Od razu daje +5 miejsc
			new_components.append(backpack)
			
		8: # Budowla
			var place = PlaceableComponent.new()
			new_components.append(place)
			var stack = StackComponent.new()
			stack.max_stack = 1
			new_components.append(stack)
			
		9: # Surowiec
			var stack = StackComponent.new()
			stack.max_stack = 16
			new_components.append(stack)
			
	item.components = new_components
	item.emit_changed()
	print("Wtyczka: Zaaplikowano zoptymalizowany szablon do: ", item.resource_path.get_file())
