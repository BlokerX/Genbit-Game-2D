class_name CraftingSystem 
extends RefCounted

static func can_craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if not recipe or recipe.results.is_empty(): 
		return false
		
	for ingredient in recipe.ingredients:
		if ingredient.required_tag != &"":
			# Weryfikacja po Tagu
			if not inventory.has_items_by_tag(ingredient.required_tag, ingredient.required_amount):
				return false
		elif ingredient.item_data != null:
			# Weryfikacja po Konkretnym Przedmiocie
			if not inventory.has_items(ingredient.item_data.item_id, ingredient.required_amount):
				return false
	return true

static func craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if not can_craft(inventory, recipe): return false
	
	# 1. Zabranie składników
	for ingredient in recipe.ingredients:
		if ingredient.required_tag != &"":
			inventory.consume_by_tag(ingredient.required_tag, ingredient.required_amount)
		elif ingredient.item_data != null:
			inventory.consume_ingredients(ingredient.item_data.item_id, ingredient.required_amount)
			
	# 2. Przyznanie wszystkich nagród
	for result in recipe.results:
		if result.item_data == null: continue
		var unique_result_data = result.item_data.duplicate(true)
		var amount_to_give = randi_range(result.min_amount, result.max_amount)
		
		var leftovers = inventory.add_item(unique_result_data, amount_to_give)
		if leftovers > 0:
			var leftover_instance = ItemInstance.new(unique_result_data, leftovers)
			inventory.item_dropped.emit(leftover_instance, false)
			
	print("Crafting: Przetworzono przepis: ", recipe.recipe_name)
	return true
