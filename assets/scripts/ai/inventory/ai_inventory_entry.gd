extends Resource
class_name AIInventoryEntry

@export var item_data: ItemData
@export var amount: int = 1
## Jeśli odznaczone, potwór zniknie razem z tym przedmiotem (nie upuści go).
@export var drop_on_death: bool = true
## Jeśli zaznaczysz to na 'false', AI nigdy nie weźmie tego do rąk (czysty loot).
@export var is_usable_by_ai: bool = true
