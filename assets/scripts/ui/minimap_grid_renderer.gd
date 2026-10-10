extends Control
class_name MinimapGridRenderer

var level_manager: Map
var cell_size: float = 32.0
var cell_spacing: float = 4.0
var is_map_toggled_large: bool = false
var current_map_region_color: Color = Color(1.0, 1.0, 1.0, 0.9)
var visited_map_region_color: Color = Color(0.6, 0.6, 0.6, 0.8)
var discovered_not_visited_color: Color = Color(0.3, 0.3, 0.3, 0.6)
var background_color: Color = Color(0.0, 0.0, 0.0, 0.5)
var original_bg_color: Color = Color(0.0, 0.0, 0.0, 0.5)
var text_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var opacity_preview: float = 0.8
var opacity_fullscreen: float = 1.0
var camera_mode_active: bool = false

func _draw() -> void:
	var current_opacity = opacity_fullscreen if is_map_toggled_large else opacity_preview
	var draw_bg = original_bg_color
	draw_bg.a *= current_opacity

	if camera_mode_active:
		draw_rect(Rect2(Vector2.ZERO, size), draw_bg)
		return

	if not is_instance_valid(level_manager) or not is_instance_valid(level_manager.current_map_region):
		return

	var current_map_region = level_manager.current_map_region
	var center_pos = size / 2.0

	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	var reference_pos = current_map_region.map_position
	var current_zoom = 1.0

	if is_map_toggled_large and level_manager.discovered_map_regions.size() > 0:
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)

		for region in level_manager.discovered_map_regions:
			min_pos.x = min(min_pos.x, region.map_position.x)
			min_pos.y = min(min_pos.y, region.map_position.y)
			max_pos.x = max(max_pos.x, region.map_position.x)
			max_pos.y = max(max_pos.y, region.map_position.y)

		reference_pos = (min_pos + max_pos) / 2.0

		var grid_w = max_pos.x - min_pos.x + 1
		var grid_h = max_pos.y - min_pos.y + 1
		var map_pixel_w = grid_w * (cell_size + cell_spacing)
		var map_pixel_h = grid_h * (cell_size + cell_spacing)

		if map_pixel_w > size.x or map_pixel_h > size.y:
			current_zoom = min(size.x / map_pixel_w, size.y / map_pixel_h) * 0.9

	var actual_cell_size = cell_size * current_zoom
	var actual_spacing = cell_spacing * current_zoom
	var font = get_theme_default_font()
	var font_size = max(1, int(actual_cell_size * 0.8))

	for map_region in level_manager.all_map_regions:
		if not level_manager.discovered_map_regions.has(map_region):
			continue

		var diff_x = map_region.map_position.x - reference_pos.x
		var diff_y = map_region.map_position.y - reference_pos.y
		var offset = Vector2(diff_x, diff_y) * (actual_cell_size + actual_spacing)
		var box_pos = center_pos + offset - Vector2(actual_cell_size / 2.0, actual_cell_size / 2.0)
		var box_rect = Rect2(box_pos, Vector2(actual_cell_size, actual_cell_size))

		var draw_color = discovered_not_visited_color
		if map_region == current_map_region:
			draw_color = current_map_region_color
		elif level_manager.visited_map_regions.has(map_region):
			draw_color = visited_map_region_color

		draw_color.a *= current_opacity
		draw_rect(box_rect, draw_color)

		if map_region == level_manager.starting_map_region:
			var text = "S"
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = box_pos + (Vector2(actual_cell_size, actual_cell_size) / 2.0)
			text_pos.y += text_size.y / 4.0

			var final_txt_color = text_color
			final_txt_color.a *= current_opacity
			draw_string(
				font,
				text_pos - Vector2(text_size.x / 2.0, 0),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				final_txt_color
			)

		if level_manager.visited_map_regions.has(map_region):
			var loot_icons_to_draw: Array[Texture2D] = []
			for child in map_region.get_children():
				if (
					child is ItemPickup
					and child.item != null
					and child.item.data != null
					and child.item.data.item_icon != null
				):
					var item_texture = child.item.data.item_icon
					if not loot_icons_to_draw.has(item_texture):
						loot_icons_to_draw.append(item_texture)

			var base_icon_size = Vector2(10, 10)
			var loot_icon_size = base_icon_size * current_zoom
			var icon_spacing = 2.0 * current_zoom
			var padding = 1.0 * current_zoom
			var current_x_offset = 0.0
			var current_y_offset = 0.0

			for texture in loot_icons_to_draw:
				if current_x_offset + loot_icon_size.x + icon_spacing > actual_cell_size:
					current_x_offset = 0.0
					current_y_offset += loot_icon_size.y + padding
				if current_y_offset + loot_icon_size.y + icon_spacing > actual_cell_size:
					break

				var loot_icon_pos = box_pos + Vector2(
					actual_cell_size - loot_icon_size.x - icon_spacing - current_x_offset,
					actual_cell_size - loot_icon_size.y - icon_spacing - current_y_offset
				)
				draw_texture_rect(
					texture,
					Rect2(loot_icon_pos, loot_icon_size),
					false,
					Color(1, 1, 1, current_opacity)
				)
				current_x_offset += loot_icon_size.x + padding
