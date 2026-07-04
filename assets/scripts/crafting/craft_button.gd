extends Button

@export var player: PlayerCharacter
@export var recipe_to_craft: CraftingRecipe

func _on_pressed():
	# Wywołujemy nasz statyczny system!
	CraftingSystem.craft(player.inventory, recipe_to_craft)
