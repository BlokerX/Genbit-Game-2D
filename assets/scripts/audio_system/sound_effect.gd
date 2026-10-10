class_name SoundEffect
extends Resource

@export_group("Dźwięk")
## Strumień dźwiękowy odtwarzany dla tego efektu.
@export var audio_stream: AudioStream

## Magistrala audio; domyślnie używa kanału SFX konfigurowanego w ustawieniach gry.
@export var bus_name: StringName = &"SFX"

## Względna głośność efektu w decybelach.
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0

@export_subgroup("Losowość")
## Minimalny mnożnik wysokości dźwięku dla drobnej wariacji odtworzeń.
@export_range(0.01, 4.0, 0.01) var pitch_min: float = 1.0

## Maksymalny mnożnik wysokości dźwięku dla drobnej wariacji odtworzeń.
@export_range(0.01, 4.0, 0.01) var pitch_max: float = 1.0

@export_subgroup("Dźwięk przestrzenny")
## Maksymalny zasięg słyszalności przy odtwarzaniu z emiterem 2D.
@export_range(0.0, 10000.0, 1.0) var max_distance: float = 2000.0
