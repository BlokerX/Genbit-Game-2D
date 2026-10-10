class_name PlayerFeedbackBurst
extends Node2D

const EFFECT_DURATION := 0.38
const LINE_COUNT := 8

var _style: String = "Burst"
var _tint: Color = Color.WHITE
var _progress: float = 0.0

## Ustawia styl i kolor przekazane przez zasób VisualEffect przed dodaniem do drzewa.
func configure_effect(style: String, tint: Color) -> void:
	_style = style
	_tint = tint

func _process(delta: float) -> void:
	_progress = minf(_progress + delta / EFFECT_DURATION, 1.0)
	queue_redraw()
	if _progress >= 1.0:
		queue_free()

func _draw() -> void:
	var fade := 1.0 - _progress
	var radius := lerpf(7.0, 48.0, _progress)
	var color := _tint
	color.a *= fade
	match _style:
		"Slash":
			_draw_slash(radius, color)
		"Impact":
			_draw_impact(radius, color)
		"Frost":
			_draw_frost(radius, color)
		"Death":
			_draw_death(radius, color)
		_:
			_draw_burst(radius, color)

func _draw_slash(radius: float, color: Color) -> void:
	var start_angle := lerpf(-0.8, -0.2, _progress)
	draw_arc(Vector2.ZERO, radius, start_angle, start_angle + 2.8, 24, color, 4.0, true)

func _draw_impact(radius: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0, true)
	draw_circle(Vector2.ZERO, radius * 0.18 * (1.0 - _progress), color)

func _draw_frost(radius: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 2.0, true)
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var direction := Vector2.from_angle(angle)
		draw_line(direction * (radius * 0.2), direction * radius, color, 2.5, true)
		draw_line(
			direction * radius * 0.72,
			direction.rotated(0.45) * radius * 0.52,
			color,
			1.5,
			true
		)

func _draw_death(radius: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0, true)
	draw_line(Vector2(-radius * 0.6, 0.0), Vector2(radius * 0.6, 0.0), color, 2.0, true)
	draw_line(Vector2(0.0, -radius * 0.6), Vector2(0.0, radius * 0.6), color, 2.0, true)

func _draw_burst(radius: float, color: Color) -> void:
	for index in range(LINE_COUNT):
		var angle := TAU * float(index) / LINE_COUNT
		var direction := Vector2.from_angle(angle)
		draw_line(direction * (radius * 0.25), direction * radius, color, 2.5, true)
