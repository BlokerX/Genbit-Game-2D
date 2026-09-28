extends Resource
class_name GuaranteedLootEntry

@export var item_data: ItemData
@export var amount: int = 1

@export_group("Opcje Skrzyni")
## Zostaw -1, aby gra wrzuciła przedmiot w pierwsze wolne miejsce.
## Wpisz 0 lub więcej (np. 0, 1, 2), aby wymusić umieszczenie w konkretnej kratce.
@export var target_slot: int = -1
