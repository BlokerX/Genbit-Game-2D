extends ItemData

class_name UseableItem

# Nowa zmienna przechowująca wszystkie efekty przedmiotu
@export var effects : Array[Effect] = []

#region Cooldown

@export var use_cooldown : float = 1.0
var use_cooldown_timer : float = 0.0

# Odlicza czas na timerze do uzyskania liczby nie dodatniej
func cooldown_process(delta : float) -> void :
	if use_cooldown_timer > 0 :
		use_cooldown_timer -= delta

func is_ready_to_use() -> bool :
	return use_cooldown_timer <= 0

func start_cooldown_timer() -> void :
	use_cooldown_timer = use_cooldown

#endregion

# Constructor
func _init(
# Argumenty dla rodzica:
 _item_id : int = 1,
 _item_name : String = "Useable Item",
 _item_type : String = "Useable",
 _item_description : String = "",
 _item_is_stackable : bool = false,
 _item_stack_count : int = 1,
 _item_max_stack_count : int = 1,
 _item_sprite : Texture2D = null,
 _durable : int = -1,
 _max_durable : int = -1,
# Argumenty dla aktualnego obiektu:
 _effects : Array[Effect] = [], # NOWY ARGUMENT
 _use_cooldown : float = 1.0
) :
	# Inicjalizacja dla klasy bazowej
	super(_item_id, _item_name, _item_type, _item_description, _item_is_stackable, _item_stack_count, _item_max_stack_count, _item_sprite, _durable, _max_durable)
	
	# Inicjalizacja dla aktualnej klasy
	effects = _effects
	use_cooldown = _use_cooldown

func use() -> bool:
	if !is_ready_to_use() :
		print("Przedmiot nie jest gotowy do użycia!")
		return false
	start_cooldown_timer()
	print("Player used " + item_name + "!")
	return true

func affect_target(target : CharacterBody2D) -> bool:
	if !is_ready_to_use() :
		return false
		
	return true

# NOWA METODA: Nakłada wszystkie przypisane efekty na cel
func apply_all_effects(target: CharacterBody2D) -> bool:
	if !use():
		return false # Przerywamy, jeśli przedmiot ma cooldown
		
	var any_effect_applied = false
	for effect in effects:
		if effect != null:
			if effect.apply_effect(target):
				any_effect_applied = true
				
	return any_effect_applied
