class_name MapDoorGenerator
extends RefCounted

const BOSS_DOOR_TEXTURE = preload("res://assets/textures/samples_examples/door/red_door.png")
const SHOP_DOOR_TEXTURE = preload("res://assets/textures/samples_examples/door/purple_door.png")
const TREASURE_DOOR_TEXTURE = preload("res://assets/textures/samples_examples/door/orange_door.png")
const DEV_ROOM_DOOR_TEXTURE = preload("res://assets/textures/samples_examples/door/black_door.png")
const ARENA_DOOR_TEXTURE = preload("res://assets/textures/samples_examples/door/dark_blue_door.png")

var _door_scene: PackedScene
var _default_door_texture: Texture2D

func configure(door_scene: PackedScene, default_door_texture: Texture2D) -> void:
	_door_scene = door_scene
	_default_door_texture = default_door_texture

func spawn_missing_doors(region_grid: Dictionary) -> void:
	if _door_scene == null:
		return

	for coords in region_grid:
		var map_region: MapRegion = region_grid[coords]

		var right_coords: Vector2i = coords + Vector2i(1, 0)
		if region_grid.has(right_coords):
			var right_region: MapRegion = region_grid[right_coords]
			if map_region.allow_door_right and right_region.allow_door_left:
				_sync_door_pair(
					map_region,
					Door.Direction.RIGHT,
					right_region,
					Door.Direction.LEFT
				)

		var down_coords: Vector2i = coords + Vector2i(0, 1)
		if region_grid.has(down_coords):
			var down_region: MapRegion = region_grid[down_coords]
			if map_region.allow_door_down and down_region.allow_door_up:
				_sync_door_pair(
					map_region,
					Door.Direction.DOWN,
					down_region,
					Door.Direction.UP
				)

func link_doors(regions: Array[MapRegion], region_grid: Dictionary) -> void:
	for map_region in regions:
		for door in map_region.doors:
			if door.destination_door != null:
				continue

			var offset: Vector2i = door.get_direction_offset()
			if offset == Vector2i.ZERO:
				continue

			var target_coords: Vector2i = map_region.map_position + offset
			var neighbor_region: MapRegion = region_grid.get(target_coords)
			if neighbor_region == null:
				continue

			_link_to_opposite_door(door, offset, neighbor_region, map_region)

func _sync_door_pair(
	map_region_a: MapRegion,
	direction_a: Door.Direction,
	map_region_b: MapRegion,
	direction_b: Door.Direction
) -> void:
	var door_a: Door = map_region_a.get_door(direction_a)
	var door_b: Door = map_region_b.get_door(direction_b)
	if door_a != null and door_b != null:
		return

	if door_a == null and door_b == null:
		var shared_texture := _get_best_door_texture(map_region_a, map_region_b)
		map_region_a.spawn_auto_door(direction_a, _door_scene, shared_texture)
		map_region_b.spawn_auto_door(direction_b, _door_scene, shared_texture)
	elif door_a != null:
		var inherited_texture := _get_manual_door_texture(door_a)
		map_region_b.spawn_auto_door(direction_b, _door_scene, inherited_texture)
	else:
		var inherited_texture := _get_manual_door_texture(door_b)
		map_region_a.spawn_auto_door(direction_a, _door_scene, inherited_texture)

func _link_to_opposite_door(
	door: Door,
	offset: Vector2i,
	neighbor_region: MapRegion,
	map_region: MapRegion
) -> void:
	var opposite_offset := -offset
	for neighbor_door in neighbor_region.doors:
		if (
			neighbor_door.destination_door == null
			and neighbor_door.get_direction_offset() == opposite_offset
		):
			door.destination_door = neighbor_door
			neighbor_door.destination_door = door
			print(
				"Map: Zszyto automatycznie drzwi między [",
				map_region.name,
				"] a [",
				neighbor_region.name,
				"]"
			)
			return

func _get_best_door_texture(region_a: MapRegion, region_b: MapRegion) -> Texture2D:
	if region_a.custom_door_texture != null:
		return region_a.custom_door_texture
	if region_b.custom_door_texture != null:
		return region_b.custom_door_texture

	var weight_a := _get_region_type_weight(region_a.map_region_type)
	var weight_b := _get_region_type_weight(region_b.map_region_type)
	if weight_a > 0 or weight_b > 0:
		if weight_a >= weight_b:
			return _get_door_texture_for_region_type(region_a.map_region_type)
		return _get_door_texture_for_region_type(region_b.map_region_type)

	return _default_door_texture

func _get_region_type_weight(region_type: MapRegion.MapRegionType) -> int:
	match region_type:
		MapRegion.MapRegionType.BOSS:
			return 100
		MapRegion.MapRegionType.TREASURE:
			return 80
		MapRegion.MapRegionType.SHOP:
			return 60
		MapRegion.MapRegionType.ARENA:
			return 40
		MapRegion.MapRegionType.DEV_ROOM:
			return 20
		MapRegion.MapRegionType.START:
			return 10
	return 0

func _get_manual_door_texture(door: Door) -> Texture2D:
	if door.door_texture != null:
		return door.door_texture

	var sprite: Sprite2D = door.get_node_or_null("Sprite2D")
	if sprite != null and sprite.texture != null:
		return sprite.texture
	return null

func _get_door_texture_for_region_type(region_type: MapRegion.MapRegionType) -> Texture2D:
	match region_type:
		MapRegion.MapRegionType.BOSS:
			return BOSS_DOOR_TEXTURE
		MapRegion.MapRegionType.SHOP:
			return SHOP_DOOR_TEXTURE
		MapRegion.MapRegionType.TREASURE:
			return TREASURE_DOOR_TEXTURE
		MapRegion.MapRegionType.DEV_ROOM:
			return DEV_ROOM_DOOR_TEXTURE
		MapRegion.MapRegionType.ARENA:
			return ARENA_DOOR_TEXTURE
	return null
