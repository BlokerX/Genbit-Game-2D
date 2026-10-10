class_name MinimapMapController
extends RefCounted

const MINIMAP_METADATA_PATH := \
	"res://assets/scenes/map_system/maps/minimaps_generated_data/minimaps_metadata.json"

var _level_manager: Map
var _map_sprite: Sprite2D
var _use_developer_physical_camera: bool = false
var _map_state_changed_callback: Callable

func initialize(map_sprite: Sprite2D, use_developer_physical_camera: bool) -> void:
	_map_sprite = map_sprite
	_use_developer_physical_camera = use_developer_physical_camera

func set_developer_camera_enabled(enabled: bool) -> void:
	_use_developer_physical_camera = enabled

func bind(level_manager: Map, map_state_changed_callback: Callable) -> void:
	if not is_instance_valid(level_manager):
		return

	if _level_manager != level_manager:
		unbind()
		_level_manager = level_manager
		_map_state_changed_callback = map_state_changed_callback

	if not _level_manager.map_region_changed.is_connected(_map_state_changed_callback):
		_level_manager.map_region_changed.connect(_map_state_changed_callback)
	if not _level_manager.map_updated.is_connected(_map_state_changed_callback):
		_level_manager.map_updated.connect(_map_state_changed_callback)

	load_automatic_minimap_data()

func unbind() -> void:
	if is_instance_valid(_level_manager):
		if (
			_map_state_changed_callback.is_valid()
			and _level_manager.map_region_changed.is_connected(_map_state_changed_callback)
		):
			_level_manager.map_region_changed.disconnect(_map_state_changed_callback)
		if (
			_map_state_changed_callback.is_valid()
			and _level_manager.map_updated.is_connected(_map_state_changed_callback)
		):
			_level_manager.map_updated.disconnect(_map_state_changed_callback)

	_level_manager = null
	_map_state_changed_callback = Callable()

func load_automatic_minimap_data() -> void:
	if not is_instance_valid(_level_manager):
		return
	if not is_instance_valid(_map_sprite) or _use_developer_physical_camera:
		return

	_map_sprite.texture = null

	var map_path := _level_manager.scene_file_path
	if map_path.is_empty() and "source_level_path" in _level_manager:
		map_path = _level_manager.source_level_path
	if map_path.is_empty():
		return

	if not FileAccess.file_exists(MINIMAP_METADATA_PATH):
		print("Minimapa: Brak pliku metadata.json. Czy uruchomiono generator?")
		return

	var file := FileAccess.open(MINIMAP_METADATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Minimapa: Nie można otworzyć pliku metadata.json.")
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		push_error("Minimapa: Nie można odczytać metadata.json: %s" % json.get_error_message())
		return

	var metadata: Variant = json.get_data()
	if not metadata is Dictionary or not metadata.has(map_path):
		return

	var map_data: Variant = metadata[map_path]
	if not map_data is Dictionary:
		push_warning("Minimapa: Nieprawidłowe metadane dla mapy: %s" % map_path)
		return

	var texture_path: Variant = map_data.get("texture_path")
	var offset_x: Variant = map_data.get("offset_x")
	var offset_y: Variant = map_data.get("offset_y")
	var texture_scale: Variant = map_data.get("scale")
	var has_valid_offset_x := offset_x is float or offset_x is int
	var has_valid_offset_y := offset_y is float or offset_y is int
	var has_valid_texture_scale := texture_scale is float or texture_scale is int
	if (
		not texture_path is String
		or not has_valid_offset_x
		or not has_valid_offset_y
		or not has_valid_texture_scale
	):
		push_warning("Minimapa: Niekompletne metadane dla mapy: %s" % map_path)
		return

	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Minimapa: Nie można wczytać tekstury: %s" % texture_path)
		return

	_map_sprite.texture = texture
	_map_sprite.position = Vector2(offset_x, offset_y)
	_map_sprite.scale = Vector2(texture_scale, texture_scale)
	print("UI Minimapa: Automatycznie załadowano grafikę dla: ", map_path.get_file())
