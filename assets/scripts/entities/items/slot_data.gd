extends Resource
class_name SlotData

## Sygnał pęknięcia
signal item_broken(item_name : String)
#signal slot_emptied()

# Wskaźnik na nasz plik z bazą danych (szablon)
@export var item_data: ItemData
# Ile sztuk tego przedmiotu mamy w tym slocie
@export var stack_amount: int = 1
# W jakim stanie jest ten konkretny przedmiot
@export var current_durability: int = -1 

func set_item(new_item: ItemData, new_stack_amount: int = 1) -> void:
	item_data = new_item
	stack_amount = new_stack_amount
	if item_data and item_data.max_durable > 0:
		current_durability = item_data.max_durable
	else:
		## domyślnie albo ujemne zawsze sprowadzamy do -1 czyli niezniszczalne
		current_durability = -1
	

#region Stack ammount / durability alghoritm

func reduce_durability(points : int = 1) -> void:
	if item_data == null or item_data.max_durable == 0:
		return # Przedmiot nie ma wytrzymałości
		
	current_durability -= points
	
	## Jeśli obecny miecz się zepsuł, ale mamy jeszcze inne w stacku
	#if durable <= 0 and item_stack_count > 1:
		#item_stack_count -= 1
		#durable = max_durable # Wyciągamy nowy, świeży miecz!
		#print("Jeden miecz się zepsuł! Zostało: ", item_stack_count)
	
	if is_broken():
		item_broken.emit(item_data.item_name) # Informujemy, że OSTATNIA sztuka pękła

func repair_item() -> void:
	if item_data:
		current_durability = item_data.max_durable

func is_broken() -> bool:
	# Zwracamy true TYLKO wtedy, gdy zepsuł się OSTATNI miecz w stacku
	if item_data and item_data.max_durable > 0 and current_durability == 0 and stack_amount <= 1:
		return true
	return false
	
#endregion

## Kompleksowo czyści wszystkie informacje w slocie
func clear_slot() -> void:
	item_data = null
	stack_amount = 0
	current_durability = -1

# Mały dodatek dla wygody
func is_empty() -> bool:
	return item_data == null or stack_amount <= 0
