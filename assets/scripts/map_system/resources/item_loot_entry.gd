extends Resource
class_name ItemLootEntry

@export var item_data: ItemData

@export_group("Waga i Ilość w stacku")
@export_range(0.1, 100.0, 0.1) var weight: float = 10.0
## Ile sztuk przedmiotu będzie w JEDNEJ wylosowanej kupce
@export var min_amount: int = 1
@export var max_amount: int = 1

@export_group("Opcja Multislot (Rozrzucanie)")
## W ilu MINIMALNIE osobnych kratkach (stackach) pojawi się ten przedmiot
@export var min_slots: int = 1
## W ilu MAKSYMALNIE osobnych kratkach (stackach) pojawi się ten przedmiot
@export var max_slots: int = 1
