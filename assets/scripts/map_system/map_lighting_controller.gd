extends RefCounted
class_name MapLightingController

const CENTER_LIGHT_NAME := "CenterMapRegionLight"

var _global_darkness: CanvasModulate

func initialize(global_darkness: CanvasModulate) -> void:
	if global_darkness == null:
		push_error("MapLightingController wymaga globalnego przyciemnienia mapy.")
		return
	_global_darkness = global_darkness

func apply_region(region: MapRegion) -> void:
	if not _has_global_darkness() or not is_instance_valid(region):
		return

	_global_darkness.color = _get_region_darkness_color(region)
	var center_light := _get_center_light(region)
	if center_light != null:
		center_light.energy = region.center_light_energy

func add_transition_tweens(
	tween: Tween,
	previous_region: MapRegion,
	next_region: MapRegion,
	duration: float
) -> void:
	if tween == null or not tween.is_valid() or not _has_global_darkness():
		return

	if is_instance_valid(next_region):
		tween.tween_property(
			_global_darkness,
			"color",
			_get_region_darkness_color(next_region),
			duration
		)

	if is_instance_valid(previous_region) and previous_region != next_region:
		var previous_light := _get_center_light(previous_region)
		if previous_light != null:
			tween.tween_property(previous_light, "energy", 0.0, duration)

	if is_instance_valid(next_region):
		var next_light := _get_center_light(next_region)
		if next_light != null:
			next_light.energy = 0.0
			tween.tween_property(next_light, "energy", next_region.center_light_energy, duration)

func _has_global_darkness() -> bool:
	return _global_darkness != null and is_instance_valid(_global_darkness)

func _get_region_darkness_color(region: MapRegion) -> Color:
	return region.darkness_color if region.is_dark_map_region else Color.WHITE

func _get_center_light(region: MapRegion) -> PointLight2D:
	var light := region.find_child(CENTER_LIGHT_NAME, false, false)
	return light as PointLight2D
