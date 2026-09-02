extends Effect
class_name OpenMenuEffect

## Wybierz z listy menu, które ma się otworzyć po zakończeniu rozmowy
@export_enum("Inventory", "Crafting", "Shop", "QuestLog", "Map") var menu_name: String = "Inventory"

func _init() -> void:
	effect_name = "Open Menu"

func apply_effect(_target: Node2D) -> bool:
	# 1. Wysyłamy sygnał na magistralę, by UI Controller przejął kontrolę
	EventBus.emit_signal("open_fullscreen_menu", menu_name)
	
	# 2. Zamykamy aktualne okno dialogowe
	DialogueManager.end_dialogue()
	return true
