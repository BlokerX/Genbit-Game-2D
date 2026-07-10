extends Effect
class_name EnterBuildModeEffect

@export_category("Build Settings")
## Scena, która będzie stawiana (np. Skrzynia)
@export var scene_to_build: PackedScene
## Ten sam przedmiot (ItemData), do którego przypinasz ten efekt, 
## aby system wiedział co zwrócić przy anulowaniu budowy.
@export var item_to_refund: ItemData

func apply_effect(target: Node2D) -> bool:
	if scene_to_build == null or item_to_refund == null:
		push_error("EnterBuildModeEffect: Brakuje sceny lub przedmiotu zwrotnego!")
		return false
		
	# Szukamy BuilderComponent bezpośrednio na celu (Graczu)
	var builder = target.get_node_or_null("BuilderComponent")
	
	if builder and builder.has_method("start_building"):
		builder.start_building(scene_to_build, item_to_refund)
		# Zwracamy true! Ekwipunek myśli, że przedmiot został użyty (zjedzony), 
		# ale nasz BuilderComponent odda go graczowi w przypadku anulowania (PPM/Escape)
		return true 
		
	push_error("EnterBuildModeEffect: Cel (target) nie posiada węzła BuilderComponent!")
	return false
