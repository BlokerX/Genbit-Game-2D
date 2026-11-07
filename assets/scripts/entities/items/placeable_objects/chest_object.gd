extends PlacedObject
class_name ChestObject

const MAX_CHEST_DROP_SCATTER_PX: float = 25.0
const CHEST_DROP_IMPULSE_FORCE: float = 120.0

# Nadpisujemy główną funkcję z klasy PlacedObject
func _break_and_drop(return_base_item: bool) -> void:
	var storage = get_node_or_null("StorageComponent") as StorageComponent

	if storage:
		# 1. Informujemy UI o zniszczeniu, aby bezpiecznie odpięło referencje ZANIM skrzynia zniknie
		storage.storage_destroyed.emit()

		var chest_origin: Vector2 = global_position
		var parent_node: Node = get_parent()

		# 2. Wypluwamy całą zawartość (z ochroną RayCast przed wpadaniem w pobliskie ściany!)
		for slot_data in storage.slots:
			if slot_data and not slot_data.is_empty() and item_pickup_scene != null and parent_node != null:
				var item_drop = item_pickup_scene.instantiate()
				item_drop.set("item", slot_data.item)

				var random_offset: Vector2 = Vector2(
					randf_range(-MAX_CHEST_DROP_SCATTER_PX, MAX_CHEST_DROP_SCATTER_PX),
					randf_range(-MAX_CHEST_DROP_SCATTER_PX, MAX_CHEST_DROP_SCATTER_PX)
				)
				var desired_pos: Vector2 = chest_origin + random_offset
				var safe_pos: Vector2 = ItemPickup.calculate_safe_spawn_position(
					chest_origin, desired_pos, self
				)

				item_drop.global_position = safe_pos
				parent_node.call_deferred("add_child", item_drop)
				item_drop.set_deferred("global_position", safe_pos)

				if item_drop is RigidBody2D:
					var scatter_dir: Vector2 = chest_origin.direction_to(safe_pos)
					if scatter_dir == Vector2.ZERO:
						scatter_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
					item_drop.call_deferred("apply_central_impulse", scatter_dir * CHEST_DROP_IMPULSE_FORCE)

	# 3. Wywołujemy logikę bazową (usuwa skrzynię i ew. wyrzuca samą skrzynię jako item)
	super._break_and_drop(return_base_item)
