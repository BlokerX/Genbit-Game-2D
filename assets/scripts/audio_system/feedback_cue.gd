class_name FeedbackCue
extends Resource

const AnimationEffectType = preload("res://assets/scripts/audio_system/animation_effect.gd")
const SoundEffectType = preload("res://assets/scripts/audio_system/sound_effect.gd")
const VisualEffectType = preload("res://assets/scripts/audio_system/visual_effect.gd")

@export_group("Oprawa akcji")
## Animacja odtwarzana na wskazanym węźle postaci lub obiektu.
@export var animation_effect: AnimationEffectType

## Efekt cząsteczkowy lub animowana scena umieszczana w świecie gry.
@export var visual_effect: VisualEffectType

## Dźwięk przestrzenny albo globalny.
@export var sound_effect: SoundEffectType
