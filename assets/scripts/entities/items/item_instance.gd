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

# =====================================================================
# SYSTEM ŁĄCZENIA I PORÓWNYWANIA PRZEDMIOTÓW (REFLEKSJA)
# =====================================================================

## Sprawdza, czy ten przedmiot można połączyć w stack z innym
func can_stack_with(other: ItemInstance) -> bool:
	if other == null or data == null or other.data == null:
		return false
		
	# 1. Podstawowe testy: czy są stackowalne i czy to ta sama "baza" (ID)
	if not data.item_is_stackable or data.item_id != other.data.item_id:
		return false
		
	# 2. Sprawdzanie stanu z samej instancji (np. zużycie)
	if data.max_durable > 0 and durability != other.durability:
		return false
		
	# 3. Dynamiczne, głębokie sprawdzanie WSZYSTKICH właściwości obiektu Data!
	return _are_objects_equal(data, other.data)

## W pełni zautomatyzowana funkcja korzystająca z Refleksji.
## Sprawdza każdy obiekt, każdą tablicę i każdą zagnieżdżoną zmienną (np. w AttackData, Effect)
func _are_objects_equal(obj1: Object, obj2: Object) -> bool:
	# Jeśli to dokładnie to samo miejsce w pamięci
	if obj1 == obj2: return true
	if obj1 == null or obj2 == null: return false
	
	# Jeśli to dwa różne typy skryptów (np. ItemWeapon vs ItemDistanceWeapon)
	if obj1.get_script() != obj2.get_script(): return false

	# Pobieramy pełną listę właściwości obiektu
	var properties = obj1.get_property_list()
	
	for prop in properties:
		# PROPERTY_USAGE_SCRIPT_VARIABLE (8192) - sprawdzamy TYLKO Twoje własne zmienne
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var prop_name = prop.name
			var val1 = obj1.get(prop_name)
			var val2 = obj2.get(prop_name)
			
			# Jeśli typy się nie zgadzają, odrzucamy
			if typeof(val1) != typeof(val2):
				return false
				
			# 1. SCENARIUSZ: Zmienna jest zagnieżdżonym Obiektem (np. AttackData, Effect) -> REKURENCJA
			if typeof(val1) == TYPE_OBJECT:
				if not _are_objects_equal(val1, val2):
					return false
					
			# 2. SCENARIUSZ: Zmienna jest Tablicą (np. effects: Array[Effect]) -> pętla po elementach
			elif typeof(val1) == TYPE_ARRAY:
				if val1.size() != val2.size(): 
					return false
				for i in range(val1.size()):
					var elem1 = val1[i]
					var elem2 = val2[i]
					
					# Jeśli element tablicy to obiekt (np. Effect), badamy go rekurencyjnie
					if typeof(elem1) == TYPE_OBJECT and typeof(elem2) == TYPE_OBJECT:
						if not _are_objects_equal(elem1, elem2): return false
					# W przeciwnym razie sprawdzamy zwykłą wartość (np. zwykła tablica intów)
					elif elem1 != elem2:
						return false
						
			# 3. SCENARIUSZ: Proste zmienne (int, float, bool, String)
			else:
				if val1 != val2:
					return false
					
	# Jeśli pętla nie znalazła absolutnie żadnych różnic - obiekty są w 100% klonami
	return true
