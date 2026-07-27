extends Resource
class_name ItemInstance

## Sygnał pęknięcia emitowany przez konkretną sztukę broni
signal item_broken(item_name: String)

@export var data: ItemData
## Kiedy -1 to nieskończone
@export var amount: int = 1
## Kiedy -1 to nieskończone
@export var durability: int = -1

## Konstruktor ułatwiający tworzenie nowych przedmiotów "w locie"
func _init(p_data: ItemData = null, p_amount: int = 1) -> void:
	data = p_data
	amount = p_amount
	if data and data.max_durable > 0:
		durability = data.max_durable

## Funkcja przeniesiona ze SlotData – teraz niszczy się INSTANCJA przedmiotu, a nie cały slot!
func reduce_durability(points: int = 1) -> void:
	if data == null or data.max_durable <= 0:
		return 
		
	durability -= points
	
	if is_broken():
		item_broken.emit(data.item_name) # Informujemy, że OSTATNIA sztuka pękła

func repair_item() -> void:
	if data:
		durability = data.max_durable

func is_broken() -> bool:
	# Zwracamy true TYLKO wtedy, gdy zepsuł się OSTATNI miecz w stacku
	if data and data.max_durable > 0 and durability == 0 and amount <= 1:
		return true
	return false
