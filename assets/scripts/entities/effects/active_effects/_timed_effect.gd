extends Effect
class_name TimedEffect

@export var duration : float = 5.0
@export var tick_interval : float = 1.0 # Jeśli 0, efekt nie ma "tików" (np. tylko buff do speeda)

# Nadpisujemy metodę aplikowania z bazowego Effect
func apply_effect(target : CharacterBody2D) -> bool:
	# Sprawdzamy, czy cel posiada dedykowany węzeł na efekty (effects_collector)
	var effect_parent : Node = target
	if "effects_collector" in target and target.effects_collector != null:
		effect_parent = target.effects_collector
	
	# 1. SPRAWDZAMY CZY EFEKT JUŻ ISTNIEJE NA CELU
	for child in effect_parent.get_children():
		# Weryfikujemy węzeł po istnieniu właściwości "effect_resource" używanej w skrypcie _active_effect.gd
		if child.get("effect_resource") != null and child.effect_resource.effect_name == self.effect_name:
			# Jeśli efekt o tej samej nazwie już tu jest, odświeżamy tylko jego czas trwania!
			child.duration = self.duration
			print("Odświeżono czas trwania efektu: ", effect_name)
			return true

	# 2. JEŚLI NIE MA TAKIEGO EFEKTU, DODAJEMY NOWY
	var active_node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/active_effects/_active_effect.gd"))
	
	active_node.name = effect_name.replace(" ", "_") 
	
	# Dodajemy węzeł aktywnego efektu do effects_collector (lub bezpośrednio do targetu w ramach fallbacku)
	effect_parent.add_child(active_node)
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
