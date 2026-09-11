extends Resource
class_name AIInventoryEntry

@export var item_data: ItemData
@export var amount: int = 1

## Jeśli odznaczone, potwór zniknie razem z tym przedmiotem (nie upuści go).
@export var drop_on_death: bool = true
