extends Resource
class_name CraftingRecipe

@export var recipe_name: String = "Nowa Receptura"

@export_group("Składniki")
## Czego potrzebujemy do wytworzenia
@export var ingredients: Array[RecipeIngredient] = []

@export_group("Wyniki")
## Lista WSZYSTKICH przedmiotów, które gracz otrzyma
@export var results: Array[RecipeResult] = []
