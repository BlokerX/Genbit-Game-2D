extends Resource
class_name RecipeIngredient

@export_group("Wymagania Składnika")
## Zostaw puste, jeśli wolisz wymagać przedmiotu po Tagu
@export var item_data: ItemData 
## Wpisz Tag (np. "wood"), jeśli gracz może użyć dowolnego przedmiotu z tym tagiem
@export var required_tag: StringName = &"" 
@export var required_amount: int = 1
