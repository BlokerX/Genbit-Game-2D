class_name MinimapMarkerRenderer
extends Control

var map_camera: Camera2D
var camera_container: SubViewportContainer
var player_marker_color: Color = Color(0.0, 1.0, 0.0, 1.0)
var manual_marker_color: Color = Color(1.0, 0.2, 0.2, 1.0)
var has_manual_marker: bool = false
var manual_marker_world_pos: Vector2 = Vector2.ZERO
var _camera_mode_active_callback: Callable

## Konfiguruje kamerę, kolory znaczników i sprawdzanie dostępności trybu kamery.
func configure(
	camera: Camera2D,
	camera_view: SubViewportContainer,
	camera_mode_active_callback: Callable,
	player_color: Color,
	manual_color: Color
) -> void:
	map_camera = camera
	camera_container = camera_view
	_camera_mode_active_callback = camera_mode_active_callback
	player_marker_color = player_color
	manual_marker_color = manual_color

## Rysuje znaczniki gracza i ręczny znacznik we współrzędnych minimapy.
func _draw() -> void:
	if (
		not _camera_mode_active_callback.is_valid()
		or not _camera_mode_active_callback.call()
		or not is_instance_valid(camera_container)
		or not camera_container.visible
		or not is_instance_valid(map_camera)
	):
		return

	var cam_center = map_camera.get_screen_center_position()
	var center_ui = size / 2.0

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var diff = player.global_position - cam_center
		var draw_pos = center_ui + (diff * map_camera.zoom.x)
		draw_circle(draw_pos, 4.0, player_marker_color)
		draw_circle(draw_pos, 6.0, Color(0, 0, 0, 0.8), false, 2.0)

	if has_manual_marker:
		_draw_manual_marker(cam_center, center_ui)

func _draw_manual_marker(cam_center: Vector2, center_ui: Vector2) -> void:
	var m_diff = manual_marker_world_pos - cam_center
	var m_draw_pos = center_ui + (m_diff * map_camera.zoom.x)
	var is_offscreen = (
		m_draw_pos.x < 0
		or m_draw_pos.y < 0
		or m_draw_pos.x > size.x
		or m_draw_pos.y > size.y
	)

	if is_offscreen:
		var margin = 15.0
		var half_w = center_ui.x - margin
		var half_h = center_ui.y - margin
		var dir = (m_draw_pos - center_ui).normalized()
		var t_x = INF
		if abs(dir.x) > 0.0001:
			t_x = half_w / abs(dir.x)
		var t_y = INF
		if abs(dir.y) > 0.0001:
			t_y = half_h / abs(dir.y)

		var t = min(t_x, t_y)
		var clamped_pos = center_ui + dir * t
		var tip = clamped_pos
		var left = clamped_pos - dir * 12.0 + dir.orthogonal() * 6.0
		var right = clamped_pos - dir * 12.0 - dir.orthogonal() * 6.0
		var points = PackedVector2Array([tip, left, right])
		var colors = PackedColorArray([manual_marker_color, manual_marker_color, manual_marker_color])

		draw_polygon(points, colors)
		draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.BLACK, 1.5)
	else:
		draw_line(m_draw_pos, m_draw_pos + Vector2(0, 12), Color(0, 0, 0, 0.8), 2.0)
		draw_line(m_draw_pos, m_draw_pos + Vector2(0, 12), manual_marker_color, 1.0)
		draw_circle(m_draw_pos, 4.5, manual_marker_color)
		draw_circle(m_draw_pos, 6.5, Color(0, 0, 0, 0.8), false, 2.0)
