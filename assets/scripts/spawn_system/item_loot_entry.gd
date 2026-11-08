extends Resource
class_name ItemLootEntry

enum DurabilityRollMode { PERCENTAGE, EXACT_VALUE }

const MIN_DURABILITY_VALUE: int = 1
const MIN_STACK_SLOTS_COUNT: int = 1

@export_group("Konfiguracja Przedmiotu")
@export var item_data: ItemData

@export_group("Waga i Ilość w stacku")
## Waga przedmiotu w losowaniu (im wyższa, tym większa szansa w Kole Fortuny)
@export_range(0.1, 100.0, 0.1) var weight: float = 10.0
## Ile sztuk przedmiotu będzie w JEDNEJ wylosowanej kupce (stacku)
@export var min_amount: int = 1
@export var max_amount: int = 1

@export_group("Wytrzymałość / Zużycie")
## Jeśli prawda, a przedmiot nie jest wieczny (max_durability > 0), to jego wytrzymałość zostanie wylosowana.
@export var randomize_durability: bool = false
## Wybierz, czy losować ułamek maksymalnego stanu, czy dokładne punkty
@export var durability_mode: DurabilityRollMode = DurabilityRollMode.PERCENTAGE

@export_subgroup("Tryb: Procentowy")
## 0.1 to 10% stanu, 1.0 to 100% stanu (nowy)
@export_range(0.01, 1.0, 0.01) var min_durability_percent: float = 0.1 
@export_range(0.01, 1.0, 0.01) var max_durability_percent: float = 1.0 

@export_subgroup("Tryb: Twarde Wartości")
## Używane tylko gdy tryb to EXACT_VALUE (Twarde cyfry)
@export var min_exact_durability: int = 1
@export var max_exact_durability: int = 10

@export_group("Opcja Multislot (Rozrzucanie)")
## W ilu MINIMALNIE osobnych kratkach (stackach) pojawi się ten przedmiot
@export var min_slots: int = 1
## W ilu MAKSYMALNIE osobnych kratkach (stackach) pojawi się ten przedmiot
@export var max_slots: int = 1

## Losuje w ilu osobnych slotach/stackach powinien pojawić się ten przedmiot.
func roll_slots_count() -> int:
	var low: int = maxi(MIN_STACK_SLOTS_COUNT, mini(min_slots, max_slots))
	var high: int = maxi(low, maxi(min_slots, max_slots))
	return randi_range(low, high)

## Tworzy gotową instancję przedmiotu (ItemInstance) z wylosowaną ilością i wytrzymałością (DRY / Flyweight).
func create_item_instance(forced_amount: int = -1) -> ItemInstance:
	if item_data == null:
		return null

	var final_amount: int = forced_amount
	if final_amount < 0:
		var low_amt: int = maxi(1, mini(min_amount, max_amount))
		var high_amt: int = maxi(low_amt, maxi(min_amount, max_amount))
		final_amount = randi_range(low_amt, high_amt)

	# Współdzielimy referencję do szablonu item_data (brak zbędnego duplicate(true) obciążającego RAM!)
	var instance: ItemInstance = ItemInstance.new(item_data, final_amount)

	var max_durability: int = 0
	if item_data.components != null:
		for comp in item_data.components:
			if comp is DurabilityComponent:
				max_durability = comp.max_durability
				break

	if max_durability > 0:
		if randomize_durability:
			var rolled_durability: int = max_durability
			if durability_mode == DurabilityRollMode.PERCENTAGE:
				var min_p: float = minf(min_durability_percent, max_durability_percent)
				var max_p: float = maxf(min_durability_percent, max_durability_percent)
				var dur_percent: float = randf_range(min_p, max_p)
				rolled_durability = int(float(max_durability) * dur_percent)
			else:
				var min_ex: int = mini(min_exact_durability, max_exact_durability)
				var max_ex: int = maxi(min_exact_durability, max_exact_durability)
				rolled_durability = randi_range(min_ex, max_ex)
			instance.state["durability"] = clampi(rolled_durability, MIN_DURABILITY_VALUE, max_durability)
		else:
			instance.state["durability"] = max_durability

	return instance
