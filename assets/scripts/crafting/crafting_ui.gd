extends Control
class_name CraftingUI
## Kontroler interfejsu rzemiosła (Crafting) obsługujący wybór receptur, podgląd składników i wytwarzanie przedmiotów.

const WINDOW_PADDING_PX: float = 22.0
const MISSING_INGREDIENT_HEX: String = "#ff6b6b"
const AVAILABLE_INGREDIENT_HEX: String = "#69db7c"
const REWARD_ITEM_HEX: String = "#ffd43b"
const SECTION_HEADER_HEX: String = "#e9ecef"

@export var player: PlayerCharacter
@export var available_recipes: Array[CraftingRecipe] = []

@onready var background_panel: Panel = $BackgroundPanel
@onready var header_label: Label = $BackgroundPanel/HBoxContainer/LeftPanel/Label
@onready var recipe_list: VBoxContainer = $BackgroundPanel/HBoxContainer/LeftPanel/ScrollContainer/RecipeList
@onready var right_panel: VBoxContainer = $BackgroundPanel/HBoxContainer/RightPanel
@onready var result_icon: TextureRect = $BackgroundPanel/HBoxContainer/RightPanel/ResultIcon
@onready var result_name: Label = $BackgroundPanel/HBoxContainer/RightPanel/ResultName
@onready var ingredients_label: RichTextLabel = $BackgroundPanel/HBoxContainer/RightPanel/IngredientsLabel
@onready var craft_button: Button = $BackgroundPanel/HBoxContainer/RightPanel/CraftButton

var selected_recipe: CraftingRecipe = null
var _recipe_buttons: Dictionary = {}

func _ready() -> void:
	hide() 
	right_panel.hide() 
	_apply_theme_styling()
	_populate_recipe_list()

	if player and player.inventory:
		player.inventory.inventory_updated.connect(_update_details_panel)
		craft_button.pressed.connect(_on_craft_button_pressed)

	# Łapanie focusu dla pada przy otwarciu ---
	visibility_changed.connect(func():
		if visible:
			_update_details_panel()
			# Czekamy klatkę, aż przyciski na pewno się wygenerują
			await get_tree().process_frame
			if recipe_list.get_child_count() > 0:
				# Zaznacza pierwszy przycisk z listy przepisów
				(recipe_list.get_child(0) as Control).grab_focus()
	)

## Aplikuje spójny styl wizualny okna rzemiosła, nagłówków oraz głównego przycisku wytwarzania.
func _apply_theme_styling() -> void:
	if background_panel != null:
		background_panel.add_theme_stylebox_override("panel", UIThemeStyler.create_window_stylebox(WINDOW_PADDING_PX))
	if header_label != null:
		UIThemeStyler.apply_readable_label_style(header_label, UIThemeStyler.HEADER_GOLD_COLOR)
	if result_name != null:
		UIThemeStyler.apply_readable_label_style(result_name, UIThemeStyler.HEADER_GOLD_COLOR)
	if craft_button != null:
		UIThemeStyler.apply_button_style(craft_button, true)

func _populate_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	_recipe_buttons.clear()

	# Zmienna do zapamiętania pierwszej poprawnej receptury
	var first_valid_recipe: CraftingRecipe = null

	for recipe in available_recipes:
		# ZABEZPIECZENIE: Sprawdzamy czy receptura ma zdefiniowane jakieś wyniki (results)
		if recipe == null or recipe.results.is_empty() or recipe.results[0].item_data == null:
			continue

		# Jeśli to pierwszy poprawny przepis na liście, zapamiętujemy go
		if first_valid_recipe == null:
			first_valid_recipe = recipe

		var btn := Button.new()
		btn.text = "  " + recipe.recipe_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Pobieramy ikonę z PIERWSZEGO przedmiotu na liście nagród
		btn.icon = recipe.results[0].item_data.item_icon 
		UIThemeStyler.apply_button_style(btn, false)

		btn.pressed.connect(func(): _select_recipe(recipe))
		recipe_list.add_child(btn)
		_recipe_buttons[recipe] = btn

	# Gdy skończymy tworzyć przyciski, automatycznie wybieramy pierwszy przepis z listy
	if first_valid_recipe != null:
		_select_recipe(first_valid_recipe)
	else:
		# Jeśli gracz nie ma żadnych dostępnych przepisów, upewniamy się, że panel jest ukryty
		right_panel.hide()

func _select_recipe(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	for rec_key in _recipe_buttons.keys():
		var btn: Button = _recipe_buttons[rec_key]
		if is_instance_valid(btn):
			UIThemeStyler.apply_button_style(btn, rec_key == selected_recipe)
	right_panel.show()
	_update_details_panel()

func _update_details_panel() -> void:
	if selected_recipe == null or selected_recipe.results.is_empty() or player == null:
		return

	# Główna ikona to ikona pierwszego z nagród
	result_icon.texture = selected_recipe.results[0].item_data.item_icon
	# Tytuł to nazwa przepisu (np. "Rozbicie butelki" albo "Kucie miecza")
	result_name.text = selected_recipe.recipe_name

	var inventory: Inventory = player.inventory

	# --- SEKCJA 1: OTRZYMASZ (CO DAJE PRZEPIS) ---
	var details_text: String = "[center][b][color=%s]Otrzymasz:[/color][/b][/center]\n" % SECTION_HEADER_HEX

	for result in selected_recipe.results:
		if result.item_data:
			# Formatowanie ilości (np. "x2" albo "x1-3", jeśli jest to losowe)
			var amount_str: String = str(result.min_amount)
			if result.min_amount != result.max_amount:
				amount_str += "-" + str(result.max_amount)

			details_text += "[color=%s]✦ %s x%s[/color]\n" % [
				REWARD_ITEM_HEX,
				result.item_data.item_name,
				amount_str
			]

	# --- SEKCJA 2: WYMAGANIA ---
	details_text += "\n[center][b][color=%s]Wymagane składniki:[/color][/b][/center]\n" % SECTION_HEADER_HEX

	for ingredient in selected_recipe.ingredients:
		var owned_amount: int = CraftingSystem.get_ingredient_available_amount(
			inventory,
			selected_recipe,
			ingredient
		)
		var required_amount: int = ingredient.required_amount
		var item_name: String = _resolve_ingredient_display_name(ingredient)
		if item_name == "":
			continue # Pusty składnik, ignorujemy

		# Kolorowanie na zielono/czerwono ze znacznikiem stanu
		var has_enough: bool = owned_amount >= required_amount
		var color_hex: String = AVAILABLE_INGREDIENT_HEX if has_enough else MISSING_INGREDIENT_HEX
		var status_symbol: String = "✔ " if has_enough else "✖ "
		details_text += "[color=%s]  %s%s: %d / %d[/color]\n" % [
			color_hex,
			status_symbol,
			item_name,
			owned_amount,
			required_amount
		]

	ingredients_label.text = details_text
	craft_button.disabled = not CraftingSystem.can_craft(inventory, selected_recipe)

## Rozpoznaje wyświetlaną nazwę składnika (po Tagu lub po konkretnym ItemData).
func _resolve_ingredient_display_name(ingredient: RecipeIngredient) -> String:
	if ingredient == null:
		return ""
	if ingredient.required_tag != &"":
		return "Dowolne: " + str(ingredient.required_tag)
	if ingredient.item_data != null:
		return ingredient.item_data.item_name
	return ""

func _on_craft_button_pressed() -> void:
	if selected_recipe != null and player != null:
		var success: bool = CraftingSystem.craft(player.inventory, selected_recipe)
		if success:
			print("CraftingUI: Pomyślnie użyto receptury!")
