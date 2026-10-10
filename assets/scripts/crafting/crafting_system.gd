class_name CraftingSystem 
extends RefCounted

static func can_craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if inventory == null:
		return false

	var requirements = _get_recipe_requirements(recipe)
	if requirements.is_empty():
		return false

	if recipe.equipment_upgrade_slot != EquippableComponent.EquipSlot.NONE:
		var upgrade_context = _get_equipment_upgrade_context(inventory, recipe, requirements)
		if not upgrade_context.get("valid", false):
			return false
		return inventory.has_requirements(
			upgrade_context["item_requirements"],
			upgrade_context["tag_requirements"]
		)

	return inventory.has_requirements(requirements["items"], requirements["tags"])

## Zwraca liczbę składnika dostępną dla receptury, uwzględniając jego plecakowy składnik ulepszenia.
static func get_ingredient_available_amount(
	inventory: Inventory,
	recipe: CraftingRecipe,
	ingredient: RecipeIngredient
) -> int:
	if inventory == null or recipe == null or ingredient == null:
		return 0

	var available_amount := 0
	if ingredient.required_tag != &"":
		available_amount = inventory.get_tag_amount(ingredient.required_tag)
	elif ingredient.item_data != null:
		available_amount = inventory.get_item_amount(ingredient.item_data.item_id)

	if recipe.equipment_upgrade_slot == EquippableComponent.EquipSlot.NONE:
		return available_amount

	var requirements = _get_recipe_requirements(recipe)
	var upgrade_context = _get_equipment_upgrade_context(inventory, recipe, requirements)
	if upgrade_context.get("valid", false) and upgrade_context["ingredient"] == ingredient:
		available_amount += 1
	return available_amount

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

## Sprawdza, czy receptura może atomowo zastąpić założony przedmiot jednym ze swoich wyników.
static func _get_equipment_upgrade_context(
	inventory: Inventory,
	recipe: CraftingRecipe,
	requirements: Dictionary
) -> Dictionary:
	if inventory == null or recipe == null or requirements.is_empty():
		return {"valid": false}

	var slot_type := recipe.equipment_upgrade_slot
	if slot_type == EquippableComponent.EquipSlot.NONE or not inventory.equipment_slots.has(slot_type):
		return {"valid": false}

	var equipment_slot: SlotData = inventory.equipment_slots[slot_type]
	if equipment_slot == null or equipment_slot.is_empty():
		return {"valid": false}

	var equipped_item: ItemInstance = equipment_slot.item
	if equipped_item.data == null or equipped_item.state.get("amount", 1) != 1:
		return {"valid": false}
	if _get_equippable_slot(equipped_item.data) != slot_type:
		return {"valid": false}

	var matching_ingredient: RecipeIngredient
	for ingredient in recipe.ingredients:
		if ingredient.required_tag != &"" and equipped_item.data.has_tag(ingredient.required_tag):
			matching_ingredient = ingredient
			break
		if (
			ingredient.required_tag == &""
			and ingredient.item_data != null
			and ingredient.item_data.item_id == equipped_item.data.item_id
		):
			matching_ingredient = ingredient
			break

	if matching_ingredient == null:
		return {"valid": false}

	var replacement_result: RecipeResult
	for result in recipe.results:
		if _get_equippable_slot(result.item_data) != slot_type:
			continue
		if replacement_result != null:
			return {"valid": false}
		replacement_result = result

	if replacement_result == null:
		return {"valid": false}

	var item_requirements: Dictionary = requirements["items"].duplicate()
	var tag_requirements: Dictionary = requirements["tags"].duplicate()
	if matching_ingredient.required_tag != &"":
		tag_requirements[matching_ingredient.required_tag] -= 1
		if tag_requirements[matching_ingredient.required_tag] == 0:
			tag_requirements.erase(matching_ingredient.required_tag)
	else:
		var item_id: StringName = matching_ingredient.item_data.item_id
		item_requirements[item_id] -= 1
		if item_requirements[item_id] == 0:
			item_requirements.erase(item_id)

	return {
		"valid": true,
		"equipped_item": equipped_item,
		"ingredient": matching_ingredient,
		"replacement_result": replacement_result,
		"item_requirements": item_requirements,
		"tag_requirements": tag_requirements,
	}

static func _get_equippable_slot(item_data: ItemData) -> int:
	if item_data == null or item_data.components == null:
		return EquippableComponent.EquipSlot.NONE
	for component in item_data.components:
		if component is EquippableComponent:
			return component.equip_slot_type
	return EquippableComponent.EquipSlot.NONE

static func craft(inventory: Inventory, recipe: CraftingRecipe) -> bool:
	if inventory == null:
		return false

	var requirements = _get_recipe_requirements(recipe)
	if requirements.is_empty():
		return false

	var upgrade_context: Dictionary = {}
	if recipe.equipment_upgrade_slot != EquippableComponent.EquipSlot.NONE:
		upgrade_context = _get_equipment_upgrade_context(inventory, recipe, requirements)
		if not upgrade_context.get("valid", false):
			return false

	var result_amounts: Dictionary = {}
	for result in recipe.results:
		result_amounts[result] = randi_range(result.min_amount, result.max_amount)

	if not upgrade_context.is_empty():
		var replacement_result: RecipeResult = upgrade_context["replacement_result"]
		var replacement_data: ItemData = replacement_result.item_data.duplicate(true)
		var replacement_item := ItemInstance.new(replacement_data, 1)
		if not inventory.try_replace_equipped_item_and_consume_requirements(
			recipe.equipment_upgrade_slot,
			upgrade_context["equipped_item"],
			replacement_item,
			upgrade_context["item_requirements"],
			upgrade_context["tag_requirements"]
		):
			return false
	else:
		if not inventory.try_consume_requirements(requirements["items"], requirements["tags"]):
			return false

	# Dodajemy nagrody; jedno ulepszające wyposażenie trafia bezpośrednio do slotu wyposażenia.
	for result in recipe.results:
		var amount_to_give: int = result_amounts[result]
		if not upgrade_context.is_empty() and result == upgrade_context["replacement_result"]:
			amount_to_give -= 1
		if amount_to_give <= 0:
			continue

		var unique_result_data = result.item_data.duplicate(true)
		var leftovers = inventory.add_item(unique_result_data, amount_to_give)
		if leftovers > 0:
			var leftover_instance = ItemInstance.new(unique_result_data, leftovers)
			inventory.item_dropped.emit(leftover_instance, false)

	print("Crafting: Przetworzono przepis: ", recipe.recipe_name)
	return true
