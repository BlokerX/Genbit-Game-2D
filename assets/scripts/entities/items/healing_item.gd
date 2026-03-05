extends UseableItem
class_name HealingItem

# Unikalne właściwości dla przedmiotu leczącego
@export var heal_amount : int = 20
@export var cures_poison : bool = false

# Constructor
func _init(
	# Argumenty ogólne (dla ItemData i UseableItem):
	_item_id : int = 1,
	_item_name : String = "Health Potion",
	_item_type : String = "Consumable",
	_item_description : String = "Przywraca punkty zdrowia.",
	_item_is_stackable : bool = true, # Przedmioty leczące zazwyczaj można stackować
	_item_stack_count : int = 1,
	_item_max_stack_count : int = 1,
	_item_sprite : Texture2D = null,
	_durable : int = -1, # Przedmioty jednorazowe zazwyczaj nie mają wytrzymałości (-1)
	_max_durable : int = -1,
	_use_cooldown : float = 0.5, # Zabezpieczenie przed wypiciem 10 mikstur w sekundę
	# Argumenty dla HealingItem:
	_heal_amount : int = 20,
	_cures_poison : bool = false
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_stack_count, _item_max_stack_count, _item_sprite, _durable, _max_durable, _use_cooldown)
	
	# Inicjalizacja dla aktualnej klasy
	heal_amount = _heal_amount
	cures_poison = _cures_poison

func heal_target(target : CharacterBody2D) -> void :
	# Sprawdzenie cooldownu z klasy UseableItem
	if !super.use() :
		return
	
	# Zakładam, że w health_stats_script masz funkcję odwrotną do 'take_damage'
	# np. 'heal(amount)' lub 'restore_health(amount)'
	if target.get("health_stats_script") != null :
		target.health_stats_script.heal(heal_amount)
		
	# Opcjonalne: logika leczenia ze statusów
	#if cures_poison and target.get("status_stats_script") != null:
		#target.status_stats_script.remove_poison()
