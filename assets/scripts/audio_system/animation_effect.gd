class_name AnimationEffect
extends Resource

@export_group("Animacja")
## Nazwa animacji z AnimationPlayer lub AnimatedSprite2D.
@export var animation_name: StringName

## Mnożnik prędkości odtwarzania.
@export_range(0.01, 4.0, 0.01) var playback_speed: float = 1.0

## Czas mieszania AnimationPlayer; -1 używa domyślnej wartości, a AnimatedSprite2D ignoruje to pole.
@export_range(-1.0, 2.0, 0.01) var blend_time: float = -1.0

## Odtwarza animację od końca zamiast od początku.
@export var from_end: bool = false
