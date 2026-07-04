extends Resource
class_name CraftingRecipe

@export var recipe_name: String = "Nowa Receptura"

@export_group("Składniki")
## Czego potrzebujemy do wytworzenia
@export var ingredients: Array[RecipeIngredient] = []

@export_group("Wynik")
## Co otrzymamy po wytworzeniu
@export var result_item: ItemData
## Ile sztuk otrzymamy za jednym razem
@export var result_amount: int = 1
