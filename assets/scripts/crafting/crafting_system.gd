class_name CraftingSystem 
extends RefCounted

static func can_craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if inventory == null:
		return false

	var requirements = _get_recipe_requirements(recipe)
	if requirements.is_empty():
		return false

	return inventory.has_requirements(requirements["items"], requirements["tags"])

static func _get_recipe_requirements(recipe: CraftingRecipe) -> Dictionary:
	if recipe == null or recipe.results.is_empty():
		return {}

	for result in recipe.results:
		if result == null or result.item_data == null or result.min_amount <= 0 or result.max_amount < result.min_amount:
			return {}

	var item_requirements: Dictionary = {}
	var tag_requirements: Dictionary = {}
	for ingredient in recipe.ingredients:
		if ingredient == null or ingredient.required_amount <= 0:
			return {}
		if ingredient.required_tag != &"":
			tag_requirements[ingredient.required_tag] = tag_requirements.get(ingredient.required_tag, 0) + ingredient.required_amount
		elif ingredient.item_data != null and ingredient.item_data.item_id != &"":
			var item_id: StringName = ingredient.item_data.item_id
			item_requirements[item_id] = item_requirements.get(item_id, 0) + ingredient.required_amount
		else:
			return {}

	return {"items": item_requirements, "tags": tag_requirements}

static func craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if inventory == null:
		return false

	var requirements = _get_recipe_requirements(recipe)
	if requirements.is_empty():
		return false
	if not inventory.try_consume_requirements(requirements["items"], requirements["tags"]):
		return false
			
	# Dodajemy nagrody
	for result in recipe.results:
		var unique_result_data = result.item_data.duplicate(true)
		var amount_to_give = randi_range(result.min_amount, result.max_amount)
		
		var leftovers = inventory.add_item(unique_result_data, amount_to_give)
		if leftovers > 0:
			var leftover_instance = ItemInstance.new(unique_result_data, leftovers)
			inventory.item_dropped.emit(leftover_instance, false)
			
	print("Crafting: Przetworzono przepis: ", recipe.recipe_name)
	return true
