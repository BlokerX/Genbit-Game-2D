extends Control
class_name CraftingUI

# Definiujemy stałą z nazwą naszej akcji z Input Map
const INPUT_TOGGLE_CRAFTING = "ToggleCrafting"

@export var player: PlayerCharacter
## Tutaj w Inspektorze wrzuć wszystkie swoje pliki przepisów (.tres)
@export var available_recipes: Array[CraftingRecipe] = []

@onready var recipe_list = $BackgroundPanel/HBoxContainer/LeftPanel/ScrollContainer/RecipeList
@onready var right_panel = $BackgroundPanel/HBoxContainer/RightPanel
@onready var result_icon = $BackgroundPanel/HBoxContainer/RightPanel/ResultIcon
@onready var result_name = $BackgroundPanel/HBoxContainer/RightPanel/ResultName
@onready var ingredients_label = $BackgroundPanel/HBoxContainer/RightPanel/IngredientsLabel
@onready var craft_button = $BackgroundPanel/HBoxContainer/RightPanel/CraftButton

var selected_recipe: CraftingRecipe = null

func _ready() -> void:
	# 1. Chowamy CAŁE okno craftingu na starcie gry
	hide() 
	
	right_panel.hide() 
	_populate_recipe_list()
	
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_update_details_panel)
		craft_button.pressed.connect(_on_craft_button_pressed)

# --- NOWOŚĆ: Funkcja wyłapująca wciśnięcie klawisza ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(INPUT_TOGGLE_CRAFTING):
		# Zmienia widoczność na przeciwną (jak jest otwarte to zamknie, jak zamknięte - otworzy)
		visible = !visible
		
		# Kiedy otwieramy okno, odświeżamy surowce (bo gracz mógł w międzyczasie coś zebrać)
		if visible:
			_update_details_panel()

## Tworzy przyciski dla każdego przepisu po lewej stronie
func _populate_recipe_list() -> void:
	# Czyścimy starą listę
	for child in recipe_list.get_children():
		child.queue_free()
		
	for recipe in available_recipes:
		if recipe == null or recipe.result_item == null:
			continue
			
		var btn = Button.new()
		btn.text = recipe.recipe_name
		btn.icon = recipe.result_item.item_icon # Opcjonalnie: mała ikonka na przycisku
		# Kiedy gracz kliknie przepis, wywołujemy funkcję pokazującą detale
		btn.pressed.connect(func(): _select_recipe(recipe))
		recipe_list.add_child(btn)

## Reakcja na kliknięcie przepisu z listy
func _select_recipe(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	right_panel.show()
	_update_details_panel()

## Odświeża prawe okno (wymagania, kolory, przycisk)
func _update_details_panel() -> void:
	if selected_recipe == null:
		return
		
	result_icon.texture = selected_recipe.result_item.item_icon
	result_name.text = selected_recipe.result_item.item_name
	
	var inventory = player.inventory
	var ingredients_text = "[center]Wymagane składniki:[/center]\n"
	var can_afford_all = true
	
	for ingredient in selected_recipe.ingredients:
		var owned_amount = inventory.get_item_amount(ingredient.item_data.item_id)
		var required_amount = ingredient.required_amount
		var item_name = ingredient.item_data.item_name
		
		# Kolorowanie w stylu AAA (Czerwony brak, Zielony/Biały OK)
		if owned_amount >= required_amount:
			ingredients_text += "[color=green]✔ " + item_name + ": " + str(owned_amount) + " / " + str(required_amount) + "[/color]\n"
		else:
			ingredients_text += "[color=red]✖ " + item_name + ": " + str(owned_amount) + " / " + str(required_amount) + "[/color]\n"
			can_afford_all = false # Brakuje nam chociaż jednego surowca
			
	ingredients_label.text = ingredients_text
	
	# Zablokowanie przycisku, jeśli gracza nie stać
	craft_button.disabled = !can_afford_all

## Akcja samego wytwarzania
func _on_craft_button_pressed() -> void:
	if selected_recipe != null and player != null:
		# Używamy naszego bezpętlowego, szybkiego systemu!
		var success = CraftingSystem.craft(player.inventory, selected_recipe)
		if success:
			print("CraftingUI: Wytworzono przedmiot!")
			# UI zaktualizuje się samo, bo zużycie surowców odpali `inventory_updated`!
