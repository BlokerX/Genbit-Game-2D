extends UseableItem
class_name EatableItem

# Constructor
func _init(
	# Argumenty ogólne (dla ItemData i UseableItem):
	_item_id : int = 1,
	_item_name : String = "Health Potion",
	_item_type : String = "Eatable",
	_item_description : String = "It is possible to be eaten.",
	_item_is_stackable : bool = true, # Przedmioty leczące zazwyczaj można stackować
	_item_max_stack_count : int = 1,
	_item_sprite : Texture2D = null,
	_max_durable : int = -1,
	_effects : Array[Effect] = [], # Przekazujemy dodatkowe efekty
	_use_cooldown : float = 0.5 # Zabezpieczenie przed wypiciem 10 mikstur w sekundę
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_max_stack_count, _item_sprite, _max_durable, _effects, _use_cooldown)

func affect_target(target : CharacterEntity) -> bool :
	print("Gracz konsumuje przedmiot!")
	
	# (Opcjonalnie: aplikowanie innych efektów z tablicy 'effects' np. buff do zdrowia lub regeneracja)
	# Używamy pętli bez sprawdzania cooldownu (bo zrobiliśmy to wyżej)
	for additional_effect in effects:
		if additional_effect != null:
			if target.has_method("receive_effect"):
				target.receive_effect(additional_effect)
			else:
				additional_effect.apply_effect(target)
	
	#apply_all_effects(target) # alternatywa
	
	return true
