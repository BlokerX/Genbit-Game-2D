class_name VisualEffect
extends Resource

@export_group("Wizualny efekt")
## Scena efektu 2D. Jej root musi dziedziczyć po Node2D.
## SpriteFrames, a następnie tekstura, mają pierwszeństwo przed tą sceną.
@export var effect_scene: PackedScene

## Pojedynczy PNG używany bez tworzenia osobnej sceny efektu.
@export var texture: Texture2D

## SpriteFrames pozwala użyć animacji PNG przygotowanej w edytorze Godota.
@export var sprite_frames: SpriteFrames
@export var animation_name: String = "default"

## Skala bezpośrednio renderowanej tekstury lub animacji.
@export var texture_scale: Vector2 = Vector2.ONE

## Styl prostego efektu proceduralnego, jeśli scena go obsługuje.
@export_enum("Burst", "Slash", "Impact", "Frost", "Death") var style: String = "Burst"

## Kolor akcentu efektu proceduralnego.
@export var tint: Color = Color.WHITE

## Przesunięcie efektu względem pozycji przekazanej do GameFeedback.
@export var position_offset: Vector2 = Vector2.ZERO

## Czas życia efektu; zero pozostawia scenę i animowane SpriteFrames samodzielnym.
## Statyczny PNG z zerem jest automatycznie usuwany po 0,4 sekundy.
@export_range(0.0, 120.0, 0.1) var lifetime_seconds: float = 0.0
