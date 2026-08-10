@abstract
extends Effect
class_name TimedEffect

@export var duration : float = 5.0
## Czy efekt ma trwać wiecznie?
@export var is_infinite : bool = false 
# Jeśli 0, efekt nie ma "tików" (np. tylko buff do speeda)
@export var tick_interval : float = 1.0

# Nadpisujemy metodę aplikowania z bazowego Effect
func apply_effect(target : Node2D) -> bool:
	# Sprawdzamy, czy cel posiada dedykowany węzeł na efekty (effects_collector)
	var effect_parent : Node = target
	if "effects_collector" in target and target.effects_collector != null:
		effect_parent = target.effects_collector
	
	# 1. SPRAWDZAMY CZY EFEKT JUŻ ISTNIEJE NA CELU
	for child in effect_parent.get_children():
		# Weryfikujemy węzeł po istnieniu właściwości "effect_resource" używanej w skrypcie _active_effect.gd
		if child.get("effect_resource") != null and child.effect_resource.effect_name == self.effect_name:
			
			# Pomijamy węzły, które za ułamek sekundy i tak zostaną usunięte
			if child.is_queued_for_deletion():
				continue
			
			# Sytuacja A: Gracz ma już nieskończoną aurę pokoju, a pije zwykłą potkę.
			if child.is_infinite and not self.is_infinite:
				print("Zignorowano efekt z przedmiotu: Nieskończona aura [", effect_name, "] już działa!")
				return true # Przerywamy, aura zostaje nienaruszona
				
			# Sytuacja B: Gracz pije miksturę, ale nakładamy na niego nieskończoną aurę.
			if self.is_infinite:
				child.is_infinite = true
			
			# Sytuacja C: Odświeżamy zwykły czas. Wybieramy dłuższą wartość,
			# aby wypicie słabszej potki nie skróciło działania silniejszej!
			child.duration = max(child.duration, self.duration)
			
			print("Odświeżono czas trwania efektu: ", effect_name)
			return true

	# 2. JEŚLI NIE MA TAKIEGO EFEKTU, DODAJEMY NOWY
	var active_node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/active_effects/_active_effect.gd"))
	
	active_node.name = effect_name.replace(" ", "_") 
	
	# Dodajemy węzeł aktywnego efektu do effects_collector (lub bezpośrednio do targetu w ramach fallbacku)
	effect_parent.add_child(active_node)
	active_node.setup(target, self, duration, tick_interval, is_infinite)
	
	print("Nałożono efekt czasowy: ", effect_name)
	return true

# Metody do nadpisania w konkretnych efektach czasowych:

func on_effect_start(_target : Node2D) -> void:
	pass # Co ma się stać na samym początku?

func on_effect_tick(_target : Node2D) -> void:
	pass # Co ma się stać co każdy tick_interval?

func on_effect_end(_target : Node2D) -> void:
	pass # Co ma się stać po upływie czasu?
