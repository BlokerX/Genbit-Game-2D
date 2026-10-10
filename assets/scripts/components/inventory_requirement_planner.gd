class_name InventoryRequirementPlanner
extends RefCounted

## Przydziela składniki po ID i tagach bez przydzielania tych samych sztuk dwa razy.
static func build_plan(
	slots: Array[SlotData],
	item_requirements: Dictionary,
	tag_requirements: Dictionary
) -> Dictionary:
	var requirements: Array[Dictionary] = []
	var total_required := 0

	for item_id in item_requirements:
		var amount = item_requirements[item_id]
		if not item_id is StringName or typeof(amount) != TYPE_INT or amount <= 0:
			return {"valid": false}
		requirements.append({"item_id": item_id, "tag": &"", "amount": amount})
		total_required += amount

	for tag in tag_requirements:
		var amount = tag_requirements[tag]
		if not tag is StringName or tag == &"" or typeof(amount) != TYPE_INT or amount <= 0:
			return {"valid": false}
		requirements.append({"item_id": &"", "tag": tag, "amount": amount})
		total_required += amount

	var available_slots: Array[SlotData] = []
	var inventory_slot_indices: Array[int] = []
	for inventory_slot_index in range(slots.size()):
		var slot = slots[inventory_slot_index]
		if slot != null and not slot.is_empty():
			available_slots.append(slot)
			inventory_slot_indices.append(inventory_slot_index)

	var requirement_count = requirements.size()
	var slot_count = available_slots.size()
	var source = 0
	var first_requirement_node = 1
	var first_slot_node = first_requirement_node + requirement_count
	var sink = first_slot_node + slot_count
	var node_count = sink + 1
	var residual: Array = []
	for i in range(node_count):
		var row: Array[int] = []
		row.resize(node_count)
		row.fill(0)
		residual.append(row)

	for requirement_index in range(requirement_count):
		var requirement_node = first_requirement_node + requirement_index
		var requirement: Dictionary = requirements[requirement_index]
		var required_amount: int = requirement["amount"]
		residual[source][requirement_node] = required_amount

		for slot_index in range(slot_count):
			var slot: SlotData = available_slots[slot_index]
			if _requirement_matches_slot(requirement, slot):
				residual[requirement_node][first_slot_node + slot_index] = required_amount

	for slot_index in range(slot_count):
		var item_amount: int = available_slots[slot_index].item.state.get("amount", 1)
		residual[first_slot_node + slot_index][sink] = item_amount

	var total_consumed := 0
	while true:
		var parents: Array[int] = []
		parents.resize(node_count)
		parents.fill(-1)
		parents[source] = source
		var queue: Array[int] = [source]
		var queue_index := 0

		while queue_index < queue.size() and parents[sink] == -1:
			var current_node = queue[queue_index]
			queue_index += 1
			for next_node in range(node_count):
				if parents[next_node] == -1 and residual[current_node][next_node] > 0:
					parents[next_node] = current_node
					queue.append(next_node)
					if next_node == sink:
						break

		if parents[sink] == -1:
			break

		var flow = total_required
		var node = sink
		while node != source:
			flow = mini(flow, residual[parents[node]][node])
			node = parents[node]

		node = sink
		while node != source:
			var previous_node = parents[node]
			residual[previous_node][node] -= flow
			residual[node][previous_node] += flow
			node = previous_node
		total_consumed += flow

	if total_consumed != total_required:
		return {"valid": false}

	var slot_consumption: Dictionary = {}
	for requirement_index in range(requirement_count):
		var requirement_node = first_requirement_node + requirement_index
		var requirement: Dictionary = requirements[requirement_index]
		var required_amount: int = requirement["amount"]
		for slot_index in range(slot_count):
			var slot_node = first_slot_node + slot_index
			var slot: SlotData = available_slots[slot_index]
			if not _requirement_matches_slot(requirement, slot):
				continue

			var flow = required_amount - residual[requirement_node][slot_node]
			if flow > 0:
				var inventory_slot_index = inventory_slot_indices[slot_index]
				slot_consumption[inventory_slot_index] = slot_consumption.get(inventory_slot_index, 0) + flow

	return {"valid": true, "slot_consumption": slot_consumption}

static func _requirement_matches_slot(requirement: Dictionary, slot: SlotData) -> bool:
	var item_data: ItemData = slot.item.data
	var matches_item = requirement["item_id"] != &"" and item_data.item_id == requirement["item_id"]
	var matches_tag = requirement["tag"] != &"" and item_data.has_tag(requirement["tag"])
	return matches_item or matches_tag
