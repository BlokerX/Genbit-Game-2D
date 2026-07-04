extends Resource
class_name LootItem

@export var item_data: ItemData

@export_group("Ilość (Amount)")
## Minimalna ilość przedmiotu do wyrzucenia
@export var min_amount: int = 1
## Maksymalna ilość przedmiotu do wyrzucenia (jeśli chcesz zawsze tyle samo, ustaw min i max na tę samą wartość)
@export var max_amount: int = 1

@export_group("Szansa (Chance)")
## Szansa na wypadnięcie TEGO konkretnego przedmiotu (1.0 = 100%, 0.5 = 50%)
@export_range(0.0, 1.0) var drop_chance: float = 1.0
