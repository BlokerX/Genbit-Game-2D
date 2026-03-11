extends UseableItem
class_name HealingItem

# Unikalne właściwości dla przedmiotu leczącego
@export var heal_amount : int = 20
@export var cures_poison : bool = false
@export var allow_overheal : bool = false

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
	_effects : Array[Effect] = [], # Przekazujemy dodatkowe efekty
	_use_cooldown : float = 0.5, # Zabezpieczenie przed wypiciem 10 mikstur w sekundę
	# Argumenty dla HealingItem:
	_heal_amount : int = 20,
	_cures_poison : bool = false,
	_allow_overheal : bool = false
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_stack_count, _item_max_stack_count, _item_sprite, _durable, _max_durable, _effects, _use_cooldown)
	
	# Inicjalizacja dla aktualnej klasy
	heal_amount = _heal_amount
	cures_poison = _cures_poison
	allow_overheal = _allow_overheal

func affect_target(target : CharacterBody2D) -> bool :
	# Sprawdzenie cooldownu z klasy UseableItem
	if !super(target) :
		print("Leczenie ma cooldowna!")
		return false
	
	# Tworzymy efekt, przekazując wartość parametru overheal
	var heal_effect = HealEffect.new(heal_amount, allow_overheal)
	
	# Jeśli apply_effect zwróci false (bo HP jest pełne i overheal=false),
	# to heal_target też zwróci false, a gracz nie zużyje mikstury!
	if heal_effect.apply_effect(target):
		print("Gracz używa przedmiotu leczącego! (Leczenie: ", heal_amount, ", Usuwanie efektów trucizny: ", cures_poison, ")")
		
		# 2. Opcjonalnie: w przyszłości możesz tu dodać efekt usuwania trucizny
		# if cures_poison:
			# 	var cure_poison_effect = CurePoisonEffect.new()
			# 	cure_poison_effect.apply_effect(target)
		
		# (Opcjonalnie: aplikowanie innych efektów z tablicy 'effects')
		apply_all_effects(target)
		
		# Rozpocznyna cooldowna
		use()
		
		return true
		
	return false
