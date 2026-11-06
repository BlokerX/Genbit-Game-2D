extends TimedEffect
class_name ResizeEffect

@export var scale_modifier: float = 1.0

func _init(_duration: float = 30.0, _scale_modifier: float = 1.0) -> void:
	duration = _duration
	scale_modifier = _scale_modifier
	tick_interval = 0.0
	effect_name = "Resize"
	effect_category = EffectCategory.STAT_BUFF if _scale_modifier >= 1.0 else EffectCategory.STAT_DEBUFF

func on_effect_start(target: Node2D) -> void:
	# Pobieramy czystą skalę bazową z CharacterEntity (odporną na chwilowe powiększenie w trakcie skoku!)
	if not target.has_meta("base_scale"):
		var initial_scale: Vector2 = target.get("base_scale") if "base_scale" in target else target.scale
		target.set_meta("base_scale", initial_scale)
	if not target.has_meta("active_scale_modifiers"):
		target.set_meta("active_scale_modifiers", [])

	var modifiers: Array = target.get_meta("active_scale_modifiers")
	modifiers.append(scale_modifier)

	_apply_scale(target)

func on_effect_end(target: Node2D) -> void:
	if target.has_meta("active_scale_modifiers"):
		var modifiers: Array = target.get_meta("active_scale_modifiers")
		modifiers.erase(scale_modifier)

		if not modifiers.is_empty():
			# Jeśli działają jeszcze inne efekty zmiany rozmiaru, przeliczamy
			_apply_scale(target)
		else:
			# Koniec wszystkich efektów - wracamy do czystej bazy i sprzątamy
			var base_s: Vector2 = target.get("base_scale") if "base_scale" in target else target.get_meta("base_scale")
			target.scale = base_s
			target.remove_meta("active_scale_modifiers")

func _apply_scale(target: Node2D) -> void:
	var base_s: Vector2 = target.get("base_scale") if "base_scale" in target else target.get_meta("base_scale")
	var modifiers: Array = target.get_meta("active_scale_modifiers")

	var total_multiplier: float = 1.0
	for mod in modifiers:
		total_multiplier *= mod

	target.scale = base_s * total_multiplier
