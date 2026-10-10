class_name VisualEffect
extends Resource

@export_group("Wizualny efekt")
## Scena efektu 2D. Jej root musi dziedziczyć po Node2D.
@export var effect_scene: PackedScene

## Przesunięcie efektu względem pozycji przekazanej do GameFeedback.
@export var position_offset: Vector2 = Vector2.ZERO

## Czas życia efektu; zero oznacza, że scena zarządza własnym zakończeniem.
@export_range(0.0, 120.0, 0.1) var lifetime_seconds: float = 0.0
