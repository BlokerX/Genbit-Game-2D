class_name MinimapMapController
extends RefCounted
## Kontroler zarządzający powiązaniem minimapy z aktualnym poziomem (Map)
## oraz nieblokującym (wielowątkowym) ładowaniem wygenerowanych tekstur PNG minimapy.

const MINIMAP_METADATA_PATH: String = (
	"res://assets/scenes/map_system/maps/minimaps_generated_data/minimaps_metadata.json"
)

## Statyczny cache metadanych JSON oraz wczytanych tekstur PNG w pamięci RAM.
static var _cached_metadata: Dictionary = {}
static var _cached_textures: Dictionary = {}
static var _metadata_loaded: bool = false

var _level_manager: Map
var _map_sprite: Sprite2D
var _use_developer_physical_camera: bool = false
var _map_state_changed_callback: Callable
var _last_loaded_map_path: String = ""
var _loading_request_id: int = 0

func initialize(map_sprite: Sprite2D, use_developer_physical_camera: bool) -> void:
	_map_sprite = map_sprite
	_use_developer_physical_camera = use_developer_physical_camera

func set_developer_camera_enabled(enabled: bool) -> void:
	_use_developer_physical_camera = enabled
	if not enabled:
		_last_loaded_map_path = ""

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
	_loading_request_id += 1
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
	_last_loaded_map_path = ""

## Automatycznie ładuje plik PNG i dane po wejściu do nowej lokacji (wielowątkowo w tle - bez przycinania gry!).
func load_automatic_minimap_data() -> void:
	if not is_instance_valid(_level_manager):
		return
	if not is_instance_valid(_map_sprite) or _use_developer_physical_camera:
		return

	var map_path: String = _level_manager.scene_file_path
	if map_path.is_empty() and "source_level_path" in _level_manager:
		map_path = _level_manager.source_level_path
	if map_path.is_empty():
		_map_sprite.texture = null
		_last_loaded_map_path = ""
		return

	if map_path == _last_loaded_map_path and _map_sprite.texture != null:
		return

	var metadata: Dictionary = _get_or_load_metadata()
	if metadata.is_empty() or not metadata.has(map_path):
		_map_sprite.texture = null
		return

	var map_data: Variant = metadata[map_path]
	if not map_data is Dictionary:
		push_warning("Minimapa: Nieprawidłowe metadane dla mapy: %s" % map_path)
		return

	var texture_path: Variant = map_data.get("texture_path")
	var offset_x: Variant = map_data.get("offset_x")
	var offset_y: Variant = map_data.get("offset_y")
	var texture_scale: Variant = map_data.get("scale")

	var has_valid_offset_x: bool = offset_x is float or offset_x is int
	var has_valid_offset_y: bool = offset_y is float or offset_y is int
	var has_valid_texture_scale: bool = texture_scale is float or texture_scale is int

	if (
		not texture_path is String
		or not has_valid_offset_x
		or not has_valid_offset_y
		or not has_valid_texture_scale
	):
		push_warning("Minimapa: Niekompletne metadane dla mapy: %s" % map_path)
		return

	var tex_path_str: String = texture_path as String
	_last_loaded_map_path = map_path
	_map_sprite.position = Vector2(float(offset_x), float(offset_y))
	_map_sprite.scale = Vector2(float(texture_scale), float(texture_scale))

	# 1. Jeśli tekstura jest już w pamięci podręcznej RAM, przypisujemy ją natychmiast w O(1)
	if _cached_textures.has(tex_path_str):
		_map_sprite.texture = _cached_textures[tex_path_str]
		return

	# 2. Wielowątkowe ładowanie dużej tekstury PNG w tle (nie zamraża okna przy 8192x8192 px!)
	_load_minimap_texture_async(tex_path_str, map_path)

func _load_minimap_texture_async(tex_path: String, map_path: String) -> void:
	_loading_request_id += 1
	var req_id: int = _loading_request_id

	var err: Error = ResourceLoader.load_threaded_request(tex_path)
	if err != OK:
		var fallback_tex: Texture2D = load(tex_path) as Texture2D
		if fallback_tex != null and is_instance_valid(_map_sprite):
			_cached_textures[tex_path] = fallback_tex
			_map_sprite.texture = fallback_tex
		return

	while is_instance_valid(_map_sprite) and _map_sprite_has_tree():
		if req_id != _loading_request_id:
			return
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(tex_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_tex: Texture2D = ResourceLoader.load_threaded_get(tex_path) as Texture2D
			if loaded_tex != null:
				_cached_textures[tex_path] = loaded_tex
				if is_instance_valid(_map_sprite) and _last_loaded_map_path == map_path:
					_map_sprite.texture = loaded_tex
					print("UI Minimapa: Automatycznie załadowano grafikę dla: ", map_path.get_file())
			return
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await _map_sprite.get_tree().process_frame
		else:
			return

func _map_sprite_has_tree() -> bool:
	return is_instance_valid(_map_sprite) and _map_sprite.is_inside_tree() and _map_sprite.get_tree() != null

static func _get_or_load_metadata() -> Dictionary:
	if _metadata_loaded:
		return _cached_metadata

	_metadata_loaded = true
	if not FileAccess.file_exists(MINIMAP_METADATA_PATH):
		print("Minimapa: Brak pliku metadata.json. Czy uruchomiono generator?")
		return _cached_metadata

	var file: FileAccess = FileAccess.open(MINIMAP_METADATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Minimapa: Nie można otworzyć pliku metadata.json.")
		return _cached_metadata

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		push_error("Minimapa: Nie można odczytać metadata.json: %s" % json.get_error_message())
		return _cached_metadata

	var data: Variant = json.get_data()
	if data is Dictionary:
		_cached_metadata = data
	return _cached_metadata
