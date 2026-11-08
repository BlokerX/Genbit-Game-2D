class_name MinimapMapController
extends RefCounted
## Kontroler zarządzający powiązaniem minimapy z aktualnym poziomem (Map)
## oraz optymalnym ładowaniem wygenerowanych tekstur PNG minimapy.

const MINIMAP_METADATA_PATH: String = (
	"res://assets/scenes/map_system/maps/minimaps_generated_data/minimaps_metadata.json"
)

## Statyczny cache metadanych JSON w pamięci RAM (wczytywany z dysku tylko 1 raz na całą grę!).
static var _cached_metadata: Dictionary = {}
static var _metadata_loaded: bool = false

var _level_manager: Map
var _map_sprite: Sprite2D
var _use_developer_physical_camera: bool = false
var _map_state_changed_callback: Callable
## Ścieżka ostatnio załadowanej mapy – zapobiega wielokrotnemu wywoływaniu load() tej samej tekstury PNG!
var _last_loaded_map_path: String = ""

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

## Automatycznie ładuje plik PNG i dane po wejściu do nowej lokacji (z wykorzystaniem szybkiego cache RAM).
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

	# OPTYMALIZACJA (Brak lagów): Jeśli tekstura dla tej mapy jest już załadowana na Sprite2D, kończymy w O(1)!
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

	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Minimapa: Nie można wczytać tekstury: %s" % texture_path)
		return

	_map_sprite.texture = texture
	_map_sprite.position = Vector2(float(offset_x), float(offset_y))
	_map_sprite.scale = Vector2(float(texture_scale), float(texture_scale))
	_last_loaded_map_path = map_path
	print("UI Minimapa: Automatycznie załadowano grafikę dla: ", map_path.get_file())

## Wczytuje plik minimaps_metadata.json z dysku tylko przy pierwszym wywołaniu i przechowuje go w pamięci RAM.
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
