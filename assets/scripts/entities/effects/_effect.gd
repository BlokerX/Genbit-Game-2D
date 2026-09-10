@abstract
extends Resource

class_name Effect

@export var effect_name : String = "Effect"
@export var effect_color : Color = Color.WHITE
@export var icon : Texture2D

## Informacje o sprawcy
var source_entity: Node2D = null
var source_position: Vector2 = Vector2.ZERO

## Metoda wirtualna do nadpisania przez konkretne efekty.
## Zwraca true, jeśli efekt został pomyślnie nałożony na cel.
func apply_effect(_target : Node2D) -> bool:
	return false
