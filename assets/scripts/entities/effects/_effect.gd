extends Resource

class_name Effect

@export var effect_name : String = "Effect"

# Metoda wirtualna do nadpisania przez konkretne efekty.
# Zwraca true, jeśli efekt został pomyślnie nałożony na cel.
func apply_effect(_target : CharacterBody2D) -> bool:
	return false
