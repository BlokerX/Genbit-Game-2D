class_name MeleeWeaponComponent
extends ItemComponent

@export var attack_data: AttackData
@export var use_cooldown: float = 1.0
@export var allow_auto_aim: bool = true
@export var effects: Array[Effect] = []

## Odpalamy, gdy gracz użyje tego przedmiotu na wrogu
func execute(actor: Node2D, target: Node2D, _item_instance: ItemInstance) -> void:
	if target == null:
		return
		
	# Zabezpieczenie: Sprawdzamy czy aktor ma Twoje statystyki ataku
	var stats = actor.get("interaction_and_attack_stats_script")
	if stats == null:
		return
		
	# 1. Wgrywamy statystyki tego komponentu do gracza
	stats.change_item_cooldown(use_cooldown)
	stats.actual_attack_data = attack_data
	stats.actual_extra_effects = effects
	
	# 2. Wykonujemy cios (Twoja oryginalna funkcja!)
	stats.execute_attack_on_target(target)
	
	# 3. Psujemy broń (Zlecamy to instancji!)
	_item_instance.consume_durability(1)
	
	# 4. Prosimy ekwipunek, żeby sprawdził, czy nasza broń właśnie nie pękła
	if actor.has_method("get_inventory"):
		var inv = actor.get_inventory()
		inv.clean_dead_items()       # Czyści, jeśli ilość spadła do 0
		inv.inventory_updated.emit() # Odświeża pasek wytrzymałości w UI
