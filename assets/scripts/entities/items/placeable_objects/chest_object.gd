extends PlacedObject
class_name ChestObject

# Nadpisujemy główną funkcję z klasy PlacedObject
func _break_and_drop(return_base_item: bool) -> void:
	
	# 1. Zamknij interfejs skrzyni, jeśli była aktualnie otwarta przez gracza
	var ui = get_tree().get_first_node_in_group("UI")
	if ui and "current_open_chest" in ui and ui.current_open_chest == self:
		if ui.has_method("_close_all_ui"):
			ui._close_all_ui()
		
	# 2. Niezależnie od sposobu zniszczenia, wypluwamy cały loocik ze środka
	if has_node("StorageComponent"):
		var storage = $StorageComponent as StorageComponent
		if storage and storage.slots:
			for slot_data in storage.slots:
				if slot_data and not slot_data.is_empty() and item_pickup_scene != null:
					var item_drop = item_pickup_scene.instantiate()
					item_drop.set("item", slot_data.item)
					
					var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
					item_drop.global_position = global_position + random_offset
					get_parent().call_deferred("add_child", item_drop)
					
					if item_drop is RigidBody2D:
						var scatter_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
						item_drop.apply_central_impulse(scatter_dir * 120.0)
						
	# 3. Na sam koniec wywołujemy logikę z klasy bazowej PlacedObject!
	# Wywoła to drop samego itemu "Skrzynia" (jeśli return_base_item to true) i usunie węzeł z gry.
	super._break_and_drop(return_base_item)
