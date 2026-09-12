class_name PlaceableComponent
extends ItemComponent

@export_category("Budowanie")
@export_file("*.tscn") var scene_path: String

func execute(actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	# Jeśli to gracz - uruchamia tryb budowania kursorem
	if actor.has_method("_start_building"):
		actor._start_building(self)
	else:
		# Logika dla AI - natychmiastowe zrzucenie miny na mapę
		if scene_path == null or scene_path.is_empty(): return
		var loaded_scene = load(scene_path) as PackedScene
		if not loaded_scene: return
		
		var final_instance = loaded_scene.instantiate()
		
		# Wstrzyknięcie informacji o właścicielu (aby mina nie zabiła AI)
		if "shooter" in final_instance:
			final_instance.shooter = actor
			
		# Zapisanie DUSZY przedmiotu (by dało się go potem podnieść, jeśli ma HP)
		if final_instance is PlacedObject:
			var unique_data = _item_instance.data.duplicate(true)
			var placed_item_instance = ItemInstance.new(unique_data, 1)
			placed_item_instance.state = _item_instance.state.duplicate(true)
			placed_item_instance.state["amount"] = 1
			final_instance.saved_item_instance = placed_item_instance

		# Kładziemy obiekt delikatnie przed AI, w stronę celu
		var spawn_pos = actor.global_position
		if _target:
			spawn_pos += actor.global_position.direction_to(_target.global_position) * 35.0
			
		if actor.has_signal("entity_spawn_requested"):
			actor.emit_signal("entity_spawn_requested", final_instance, spawn_pos)
			
		# Sprawdzenie czy to AI z nieskończoną amunicją
		var has_infinite_ammo = false
		if actor.has_method("get_inventory"):
			var inv = actor.get_inventory()
			if inv and "infinite_ammo" in inv and inv.infinite_ammo == true:
				has_infinite_ammo = true
				
		# Zjadamy 1 minę z plecaka tylko, jeśli nie ma nieskończonej amunicji
		if not has_infinite_ammo:
			_item_instance.consume_amount(1)
			if actor.has_method("get_inventory"):
				var inv = actor.get_inventory()
				if inv:
					if inv.has_method("clean_dead_items"): inv.clean_dead_items()
					if inv.has_signal("inventory_updated"): inv.inventory_updated.emit()
