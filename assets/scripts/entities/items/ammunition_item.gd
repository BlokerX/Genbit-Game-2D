extends ItemData
class_name AmmunitionItem

@export_category("Ustawienia Amunicji")
## Kategoria amunicji (np. "Arrow", "9mm", "ShotgunShell"). Broń decyduje, co przyjmuje.
@export var ammunition_type: String = "Arrow"

## Opcjonalna nadpisująca tekstura pocisku (jeśli null, broń użyje swojej domyślnej)
@export var override_projectile_texture: Texture2D

@export_group("Modyfikatory Balistyczne")
## Główne obrażenia zadawane przez ten konkretny pocisk
@export var damage: int = 10

## Mnożnik prędkości (np. 1.2 = pocisk leci o 20% szybciej niż bazowa prędkość broni)
@export var speed_multiplier: float = 1.0

## Efekty nakładane po uderzeniu (np. Trucizna, Podpalenie)
@export var effects: Array[Effect]

func _init(
	_item_id: int = 1,
	_item_name: String = "Ammunition",
	_item_type: String = "Ammunition",
	_item_description: String = "",
	_item_is_stackable: bool = true,
	_item_max_stack_count: int = 100,
	_ammunition_type: String = "Arrow",
	_damage: int = 10
):
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_max_stack_count)
	ammunition_type = _ammunition_type
	damage = _damage
