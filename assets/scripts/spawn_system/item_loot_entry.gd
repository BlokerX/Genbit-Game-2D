extends Resource
class_name ItemLootEntry

enum DurabilityRollMode { PERCENTAGE, EXACT_VALUE }

@export_group("Konfiguracja Przedmiotu")
@export var item_data: ItemData

@export_group("Waga i Ilość w stacku")
## Waga przedmiotu w losowaniu (im wyższa, tym większa szansa w Kole Fortuny)
@export_range(0.1, 100.0, 0.1) var weight: float = 10.0
## Ile sztuk przedmiotu będzie w JEDNEJ wylosowanej kupce (stacku)
@export var min_amount: int = 1
@export var max_amount: int = 1

@export_group("Wytrzymałość / Zużycie")
## Jeśli prawda, a przedmiot nie jest wieczny (max_durable > 0), to jego wytrzymałość zostanie wylosowana.
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
