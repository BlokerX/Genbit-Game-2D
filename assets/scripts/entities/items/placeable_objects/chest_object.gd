extends PlacedObject
class_name ChestObject

# Nadpisujemy główną funkcję z klasy PlacedObject
func _break_and_drop(return_base_item: bool) -> void:
	var storage = get_node_or_null("StorageComponent") as StorageComponent
	if storage:
		# 1. Informujemy UI o zniszczeniu, aby bezpiecznie odpięło referencje ZANIM skrzynia zniknie
		storage.storage_destroyed.emit()
		
		# 2. Wypluwamy całą zawartość
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
					
	# 3. Wywołujemy logikę bazową (usuwa skrzynię)
	super._break_and_drop(return_base_item)
