extends Resource
class_name ItemLootEntry

@export var item_data: ItemData
@export var min_amount: int = 1
@export var max_amount: int = 1
@export_range(0.1, 100.0, 0.1) var weight: float = 10.0

# todo dodać multislotowość
@export_group("Opcja Multislot")
## Minimalna liczba slotów, które ten przedmiot zajmuje w skrzyni
@export var min_slots: int = 1
## Maksymalna liczba slotów, które ten przedmiot zajmuje w skrzyni
@export var max_slots: int = 1
