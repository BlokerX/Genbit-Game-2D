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
	var effect_parent : Node = target
	if "effects_collector" in target and target.effects_collector != null:
		effect_parent = target.effects_collector
		
	# Odczytujemy skąd pochodzi NASZ efekt
	var my_is_aura = self.has_meta("is_environment_aura") and self.get_meta("is_environment_aura") == true
	var my_passive_src = self.get_meta("passive_source") if self.has_meta("passive_source") else ""

	# 1. SPRAWDZAMY CZY EFEKT JUŻ ISTNIEJE NA CELU
	for child in effect_parent.get_children():
		if child.get("effect_resource") != null and child.effect_resource.effect_name == self.effect_name:
			var child_res = child.effect_resource
			var child_is_aura = child_res.has_meta("is_environment_aura") and child_res.get_meta("is_environment_aura") == true
			var child_passive_src = child_res.get_meta("passive_source") if child_res.has_meta("passive_source") else ""
			
			# TARCZA KANAŁÓW: Nadpisujemy efekt TYLKO jeśli pochodzi z tego samego źródła!
			# Mróz z HELD (broń) vs Mróz z INVENTORY (Plecak) vs Mróz z potki ("" puste)
			if my_is_aura == child_is_aura and my_passive_src == child_passive_src:
				if child.is_queued_for_deletion():
					continue
					
				if child.is_infinite and not self.is_infinite:
					print("Zignorowano efekt czasowy: Nieskończona wersja [", effect_name, "] już działa!")
					return true
					
				if self.is_infinite:
					child.is_infinite = true
					
				child.duration = max(child.duration, self.duration)
				print("Odnowiono czas trwania efektu: ", effect_name)
				return true

	# 2. JEŚLI NIE MA TAKIEGO EFEKTU W TYM KANALE, DODAJEMY NOWY
	var active_node = Node.new()
	active_node.set_script(preload("res://assets/scripts/entities/effects/base/_active_effect.gd"))
	active_node.name = effect_name.replace(" ", "_")
	
	effect_parent.add_child(active_node)
	active_node.setup(target, self, duration, tick_interval, is_infinite)
	print("Nałożono efekt czasowy: ", effect_name, " (Aura: ", my_is_aura, " | Equip: ", my_passive_src, ")")
	return true

# Metody do nadpisania w konkretnych efektach czasowych:

func on_effect_start(_target : Node2D) -> void:
	pass # Co ma się stać na samym początku?

func on_effect_tick(_target : Node2D) -> void:
	pass # Co ma się stać co każdy tick_interval?

func on_effect_end(_target : Node2D) -> void:
	pass # Co ma się stać po upływie czasu?
