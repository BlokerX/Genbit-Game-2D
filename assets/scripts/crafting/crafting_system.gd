class_name CraftingSystem
extends RefCounted

## Zwraca True, jeśli ekwipunek posiada wszystkie składniki.
## Dzięki cache w inventory.gd, ta funkcja działa w czasie O(1) - natychmiastowo!
static func can_craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if not recipe or not recipe.result_item: 
		return false
	
	for ingredient in recipe.ingredients:
		if not inventory.has_items(ingredient.item_data.item_id, ingredient.required_amount):
			return false
			
	return true

## Główna funkcja wykonująca wytwarzanie przedmiotu
static func craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	# 1. Błyskawiczne zabezpieczenie (czy mamy surowce)
	if not can_craft(inventory, recipe):
		print("Crafting: Brak wymaganych składników dla: ", recipe.recipe_name)
		return false
		
	# 2. Pobranie surowców (automatycznie odświeży UI ekwipunku)
	for ingredient in recipe.ingredients:
		inventory.consume_ingredients(ingredient.item_data.item_id, ingredient.required_amount)
		
	# 3. Dodanie gotowego przedmiotu do plecaka
	var leftovers = inventory.add_item(recipe.result_item, recipe.result_amount)
	
	# 4. Jeśli plecak był pełny (bo zajęliśmy wszystkie sloty), wyrzucamy resztę na ziemię
	if leftovers > 0:
		inventory.item_dropped.emit(recipe.result_item, leftovers)
		print("Crafting: Ekwipunek pełny! Wyrzucono '", recipe.result_item.item_name, "' na ziemię.")
	else:
		print("Crafting: Pomyślnie wytworzono: ", recipe.result_item.item_name)
		
	return true
