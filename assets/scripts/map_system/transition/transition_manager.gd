extends CanvasLayer

signal on_fade_out_finished
signal on_fade_in_finished

@onready var color_rect: ColorRect = ColorRect.new()

var _active_tween: Tween
var _active_target_alpha: float
var _active_completion: Callable

func _ready() -> void:
	layer = GameLayers.UI_TRANSITION # Najwyższa warstwa, by zakryć grę i UI
	
	color_rect.color = Color(0, 0, 0, 0) # Na start całkowicie przezroczysty
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

func _exit_tree() -> void:
	_cancel_active_fade()

func fade_to_black(duration: float = 0.5) -> void:
	_start_fade(1.0, duration, _emit_fade_out_finished)

func fade_to_normal(duration: float = 0.5) -> void:
	_start_fade(0.0, duration, _emit_fade_in_finished)

func _start_fade(target_alpha: float, duration: float, completion: Callable) -> void:
	_cancel_active_fade()
	_active_target_alpha = target_alpha
	_active_completion = completion
	_active_tween = create_tween()
	_active_tween.tween_property(color_rect, "color:a", target_alpha, duration).set_trans(
		Tween.TRANS_SINE
	)
	_active_tween.finished.connect(_complete_active_fade)

func _cancel_active_fade() -> void:
	if _active_tween == null or not _active_tween.is_valid():
		return

	_active_tween.kill()
	color_rect.color.a = _active_target_alpha
	_complete_active_fade()

func _complete_active_fade() -> void:
	var completion := _active_completion
	_active_tween = null
	_active_completion = Callable()
	if completion.is_valid():
		completion.call()

func _emit_fade_out_finished() -> void:
	on_fade_out_finished.emit()

func _emit_fade_in_finished() -> void:
	on_fade_in_finished.emit()
