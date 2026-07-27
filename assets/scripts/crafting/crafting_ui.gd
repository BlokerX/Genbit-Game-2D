extends Control
class_name CraftingUI

@export var player: PlayerCharacter
@export var available_recipes: Array[CraftingRecipe] = []

@onready var recipe_list = $BackgroundPanel/HBoxContainer/LeftPanel/ScrollContainer/RecipeList
@onready var right_panel = $BackgroundPanel/HBoxContainer/RightPanel
@onready var result_icon = $BackgroundPanel/HBoxContainer/RightPanel/ResultIcon
@onready var result_name = $BackgroundPanel/HBoxContainer/RightPanel/ResultName
@onready var ingredients_label = $BackgroundPanel/HBoxContainer/RightPanel/IngredientsLabel
@onready var craft_button = $BackgroundPanel/HBoxContainer/RightPanel/CraftButton

var selected_recipe: CraftingRecipe = null

func _ready() -> void:
	hide() 
	right_panel.hide() 
	_populate_recipe_list()
	
	if player and player.inventory:
		player.inventory.inventory_updated.connect(_update_details_panel)
		craft_button.pressed.connect(_on_craft_button_pressed)
	
	# Odśwież dane, gdy UIController pokaże to okno
	visibility_changed.connect(func(): if visible: _update_details_panel())

func _populate_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
		
	# Zmienna do zapamiętania pierwszej poprawnej receptury
	var first_valid_recipe: CraftingRecipe = null
		
	for recipe in available_recipes:
		# ZABEZPIECZENIE: Sprawdzamy czy receptura ma zdefiniowane jakieś wyniki (results)
		if recipe == null or recipe.results.is_empty() or recipe.results[0].item_data == null:
			continue
			
		# Jeśli to pierwszy poprawny przepis na liście, zapamiętujemy go
		if first_valid_recipe == null:
			first_valid_recipe = recipe
			
		var btn = Button.new()
		btn.text = recipe.recipe_name
		# Pobieramy ikonę z PIERWSZEGO przedmiotu na liście nagród
		btn.icon = recipe.results[0].item_data.item_icon 
		
		btn.pressed.connect(func(): _select_recipe(recipe))
		recipe_list.add_child(btn)

	# Gdy skończymy tworzyć przyciski, automatycznie wybieramy pierwszy przepis z listy
	if first_valid_recipe != null:
		_select_recipe(first_valid_recipe)
	else:
		# Jeśli gracz nie ma żadnych dostępnych przepisów, upewniamy się, że panel jest ukryty
		right_panel.hide()

func _select_recipe(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	right_panel.show()
	_update_details_panel()

func _update_details_panel() -> void:
	if selected_recipe == null or selected_recipe.results.is_empty():
		return
		
	# Główna ikona to ikona pierwszego z nagród
	result_icon.texture = selected_recipe.results[0].item_data.item_icon
	# Tytuł to nazwa przepisu (np. "Rozbicie butelki" albo "Kucie miecza")
	result_name.text = selected_recipe.recipe_name
	
	var inventory = player.inventory
	
	# --- SEKCJA 1: OTRZYMASZ (CO DAJE PRZEPIS) ---
	var details_text = "[center][b]Otrzymasz:[/b][/center]\n"
	
	for result in selected_recipe.results:
		if result.item_data:
			# Formatowanie ilości (np. "x2" albo "x1-3", jeśli jest to losowe)
			var amount_str = str(result.min_amount)
			if result.min_amount != result.max_amount:
				amount_str += "-" + str(result.max_amount)
				
			details_text += "[color=yellow]✦ " + result.item_data.item_name + " x" + amount_str + "[/color]\n"
	
	# --- SEKCJA 2: WYMAGANIA ---
	details_text += "\n[center][b]Wymagane składniki:[/b][/center]\n"
	var can_afford_all = true
	
	for ingredient in selected_recipe.ingredients:
		var owned_amount = inventory.get_item_amount(ingredient.item_data.item_id)
		var required_amount = ingredient.required_amount
		var item_name = ingredient.item_data.item_name
		
		if owned_amount >= required_amount:
			details_text += "[color=green]✔ " + item_name + ": " + str(owned_amount) + " / " + str(required_amount) + "[/color]\n"
		else:
			details_text += "[color=red]✖ " + item_name + ": " + str(owned_amount) + " / " + str(required_amount) + "[/color]\n"
			can_afford_all = false 
			
	ingredients_label.text = details_text
	craft_button.disabled = !can_afford_all

func _on_craft_button_pressed() -> void:
	if selected_recipe != null and player != null:
		var success = CraftingSystem.craft(player.inventory, selected_recipe)
		if success:
			print("CraftingUI: Pomyślnie użyto receptury!")
