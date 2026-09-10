extends Node
class_name AIInventoryController

# TARCZA ECS: Ten sygnał musi tu być, bo bronie próbują go emitować!
signal inventory_updated

@export var starting_items: Array[ItemData] = []
var items: Array[ItemInstance] = []
var current_item_index: int = 0

func _ready() -> void:
	# Generujemy wirtualne instancje dla każdego przedmiotu
	for item_data in starting_items:
		if item_data:
			items.append(ItemInstance.new(item_data.duplicate(true), 1))

func get_current_item() -> ItemInstance:
	if items.is_empty() or current_item_index >= items.size():
		return null
	return items[current_item_index]

func reload_current_weapon() -> bool:
	var inst = get_current_item()
	if not inst: return false
	
	# AI z definicji ma nieskończoną amunicję, ładujemy magazynek z powietrza
	if inst.data.components != null:
		for comp in inst.data.components:
			if comp is RangedWeaponComponent:
				inst.state["ammo_count"] = comp.magazine_capacity
				return true
	return false

# ==============================================================
# --- KOMPATYBILNOŚĆ Z EKWIPUNKIEM GRACZA (Duck Typing) ---
# ==============================================================

## Oczyszcza zepsute/zużyte bronie potwora
func clean_dead_items() -> void:
	var changed = false
	# Usuwamy od tyłu, żeby bezpiecznie usuwać indeksy z tablicy w locie
	for i in range(items.size() - 1, -1, -1):
		if items[i].state.has("amount") and items[i].state["amount"] <= 0:
			items.remove_at(i)
			changed = true
			
	# Jeśli potwór zepsuł broń, którą trzymał, cofa indeks
	if current_item_index >= items.size():
		current_item_index = max(0, items.size() - 1)
		
	if changed:
		inventory_updated.emit()

## Zabezpieczenie na wypadek, gdyby broń próbowała oddać np. łuski lub puste wiadro
func add_instance(instance: ItemInstance) -> ItemInstance:
	return instance
