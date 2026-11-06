extends TimedEffect
class_name GhostEffect

const DEFAULT_GHOST_ALPHA: float = 0.4
const DISABLED_COLLISION_BITMASK: int = 0

## Poziom przezroczystości postaci w trybie ducha (0.4 = półprzezroczysty).
@export_range(0.0, 1.0, 0.05) var ghost_alpha: float = DEFAULT_GHOST_ALPHA

func _init(_duration: float = 8.0):
	effect_name = "Ghost Mode"
	effect_color = Color.GHOST_WHITE
	effect_category = EffectCategory.UTILITY
	duration = _duration
	tick_interval = 0.0

func on_effect_start(target: Node2D) -> void:
	target.set_meta("is_ghost", true)
	target.set_meta("ghost_alpha_value", ghost_alpha)

	if target is CollisionObject2D:
		if not target.has_meta("original_layer"):
			target.set_meta("original_layer", target.collision_layer)
		if not target.has_meta("original_mask"):
			target.set_meta("original_mask", target.collision_mask)

		# layer = 0 -> inni nas nie widzą
		target.collision_layer = DISABLED_COLLISION_BITMASK
		# mask = 0 -> my nie widzimy fizyki (przenikamy przez ściany!)
		target.collision_mask = DISABLED_COLLISION_BITMASK

	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")

func on_effect_end(target: Node2D) -> void:
	if target.has_meta("is_ghost"):
		target.remove_meta("is_ghost")
	if target.has_meta("ghost_alpha_value"):
		target.remove_meta("ghost_alpha_value")

	if target is CollisionObject2D:
		if target.has_meta("original_layer"):
			target.collision_layer = target.get_meta("original_layer")
			target.remove_meta("original_layer")
		if target.has_meta("original_mask"):
			target.collision_mask = target.get_meta("original_mask")
			target.remove_meta("original_mask")

	if target.has_method("refresh_visual_appearance"):
		target.call("refresh_visual_appearance")
