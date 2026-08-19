class_name EquippableComponent
extends ItemComponent

# --- DODAJEMY ENUM ---
enum EquipSlot { NONE, HEAD, CHEST, LEGS, BOOTS, BACKPACK, ACCESSORY, AMULET }

@export_category("Ekwipunek")
## Zdefiniuj gdzie przedmiot ma być założony
@export var equip_slot_type: EquipSlot = EquipSlot.NONE

## Efekty/Buffy nakładane, dopóki przedmiot jest noszony
@export var passive_buffs: Array[Effect] = []

func execute(_actor: Node2D, _target: Node2D, _item_instance: ItemInstance) -> void:
	print("Próbuję założyć przedmiot na slot o ID: ", equip_slot_type)
