class_name MinimapCameraBoundsController
extends RefCounted

## Oblicza obszar świata i ograniczenia kamery minimapy na podstawie regionów mapy.
var world_rect: Rect2 = Rect2()
var map_center: Vector2 = Vector2.ZERO
var fit_zoom: float = 1.0

## Aktualizuje granice na podstawie widocznych lub wszystkich regionów mapy.
func calculate_bounds(
	level_manager: Map,
	include_undiscovered: bool,
	padding_px: int,
	view_size: Vector2,
	max_zoom: float,
	fallback_zoom: float
) -> void:
	if not is_instance_valid(level_manager) or level_manager.all_map_regions.is_empty():
		world_rect = Rect2()
		fit_zoom = fallback_zoom
		return

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var map_regions_found := false
	var map_regions_to_scan = (
		level_manager.all_map_regions
		if include_undiscovered
		else level_manager.discovered_map_regions
	)
	if map_regions_to_scan.is_empty() and not level_manager.discovered_map_regions.is_empty():
		map_regions_to_scan = level_manager.discovered_map_regions

	for map_region in map_regions_to_scan:
		if is_instance_valid(map_region):
			map_regions_found = true
			var region_position: Vector2 = map_region.global_position
			var region_size: Vector2 = (
				map_region.size_px
				if "size_px" in map_region
				else Vector2(1920, 1080)
			)

			min_x = min(min_x, region_position.x)
			min_y = min(min_y, region_position.y)
			max_x = max(max_x, region_position.x + region_size.x)
			max_y = max(max_y, region_position.y + region_size.y)

	if not map_regions_found:
		return

	var left := int(min_x) - padding_px
	var top := int(min_y) - padding_px
	var right := int(max_x) + padding_px
	var bottom := int(max_y) + padding_px
	world_rect = Rect2(left, top, right - left, bottom - top)
	map_center = Vector2(left + right, top + bottom) / 2.0

	if world_rect.size.x > 0.0 and world_rect.size.y > 0.0:
		var zoom_x := view_size.x / world_rect.size.x
		var zoom_y := view_size.y / world_rect.size.y
		fit_zoom = min(min(zoom_x, zoom_y), max_zoom)

## Ogranicza pozycję kamery do obliczonego obszaru mapy.
func clamp_position(position: Vector2, view_size: Vector2, zoom: float) -> Vector2:
	if world_rect.size == Vector2.ZERO:
		return position

	var half_screen := (view_size / 2.0) / zoom
	var min_x := world_rect.position.x + half_screen.x
	var max_x := world_rect.end.x - half_screen.x
	var min_y := world_rect.position.y + half_screen.y
	var max_y := world_rect.end.y - half_screen.y
	var clamped_position := position

	if min_x > max_x:
		clamped_position.x = map_center.x
	else:
		clamped_position.x = clamp(position.x, min_x, max_x)

	if min_y > max_y:
		clamped_position.y = map_center.y
	else:
		clamped_position.y = clamp(position.y, min_y, max_y)

	return clamped_position
