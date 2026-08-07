extends CanvasLayer

signal on_fade_out_finished
signal on_fade_in_finished

@onready var color_rect: ColorRect = ColorRect.new()

func _ready() -> void:
	layer = 100 # Najwyższa warstwa, by zakryć grę i UI
	
	color_rect.color = Color(0, 0, 0, 0) # Na start całkowicie przezroczysty
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

func fade_to_black(duration: float = 0.25) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	on_fade_out_finished.emit()

func fade_to_normal(duration: float = 0.25) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	on_fade_in_finished.emit()
