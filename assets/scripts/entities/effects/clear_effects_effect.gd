extends Effect
## Usuwa czasowe efekty.
class_name ClearEffectsEffect

func _init():
	effect_name = "Clear Effects"

func apply_effect(target : CharacterBody2D) -> bool:
	# 1. Preferowany sposób: Wywołujemy wbudowaną metodę postaci (którą zrobiliśmy wcześniej)
	if target.has_method("clear_all_effects"):
		target.clear_all_effects()
		print("Wyczyszczono wszystkie efekty z: ", target.name)
		return true
		
	# 2. Fallback: Jeśli postać nie ma tej metody, ale posiada effects_collector
	if "effects_collector" in target and target.effects_collector != null:
		# Sprawdzamy, czy w ogóle są jakieś efekty do usunięcia
		if target.effects_collector.get_child_count() > 0:
			for active_effect in target.effects_collector.get_children():
				if active_effect.has_method("end_effect"):
					active_effect.end_effect()
				else:
					active_effect.queue_free()
			
			print("Wyczyszczono wszystkie efekty z: ", target.name, " (użyto fallbacku)")
			return true
			
	# Zwraca false, jeśli postać nie miała efektów ani wsparcia dla ich usuwania
	return false
