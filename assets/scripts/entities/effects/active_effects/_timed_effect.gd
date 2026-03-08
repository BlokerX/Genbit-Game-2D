extends Effect
class_name TimedEffect

@export var duration : float = 5.0
@export var tick_interval : float = 1.0 # Jeśli 0, efekt nie ma "tików" (np. tylko buff do speeda)

# Nadpisujemy metodę aplikowania z bazowego Effect
func apply_effect(target : CharacterBody2D) -> bool:
	
	# 1. SPRAWDZAMY CZY EFEKT JUŻ ISTNIEJE NA CELU
	for child in target.get_children():
		if child is ActiveEffect and child.effect_resource.effect_name == self.effect_name:
			# Jeśli efekt o tej samej nazwie już tu jest, odświeżamy tylko jego czas trwania!
			child.duration = self.duration
			print("Odświeżono czas trwania efektu: ", effect_name)
			return true # Zwracamy true, bo akcja się powiodła, ale nie dodajemy nowego węzła

	# 2. JEŚLI NIE MA TAKIEGO EFEKTU, DODAJEMY NOWY (Twój stary kod)
	var active_node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/active_effects/_active_effect.gd"))
	
	# Opcjonalnie: możemy zmienić nazwę węzła dla łatwiejszego debugowania w drzewie sceny
	active_node.name = effect_name.replace(" ", "_") 
	
	target.add_child(active_node)
	active_node.setup(target, self, duration, tick_interval)
	
	print("Nałożono efekt czasowy: ", effect_name)
	return true

# Metody do nadpisania w konkretnych efektach czasowych:

func on_effect_start(target : CharacterBody2D) -> void:
	pass # Co ma się stać na samym początku?

func on_effect_tick(target : CharacterBody2D) -> void:
	pass # Co ma się stać co każdy tick_interval?

func on_effect_end(target : CharacterBody2D) -> void:
	pass # Co ma się stać po upływie czasu?
