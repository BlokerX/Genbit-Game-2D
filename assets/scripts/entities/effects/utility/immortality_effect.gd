extends TimedEffect
class_name ImmortalityEffect

const DEFAULT_IMMORTAL_TINT := Color(1.5, 1.5, 0.5, 1.0)

## Kolor poświaty (Overdrive RGB) nakładany na postać podczas trwania nieśmiertelności.
@export var immortal_tint: Color = DEFAULT_IMMORTAL_TINT

func _init(_duration: float = 10.0):
	effect_name = "Immortality"
	effect_color = Color.GOLD
	effect_category = EffectCategory.UTILITY
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	var sprite: CanvasItem = target.call("get_visual_sprite") if target.has_method("get_visual_sprite") else null
	if sprite != null and not target.has_meta("pre_immortal_color"):
		target.set_meta("pre_immortal_color", Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 1.0))

	target.set_meta("is_immortal", true)
	target.set_meta("immortal_tint_color", immortal_tint)

	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")

func on_effect_end(target: Node2D) -> void:
	if target.has_meta("is_immortal"):
		target.remove_meta("is_immortal")
	if target.has_meta("immortal_tint_color"):
		target.remove_meta("immortal_tint_color")

	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")

	if target.has_meta("pre_immortal_color"):
		target.remove_meta("pre_immortal_color")
