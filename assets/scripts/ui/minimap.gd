extends Control
class_name Minimap

const MinimapGridRendererType = preload("res://assets/scripts/ui/minimap_grid_renderer.gd")
const MinimapMapControllerType = preload("res://assets/scripts/ui/minimap_map_controller.gd")
const MinimapMarkerRendererType = preload("res://assets/scripts/ui/minimap_marker_renderer.gd")
const MinimapCameraBoundsControllerType = preload(
	"res://assets/scripts/ui/minimap_camera_bounds_controller.gd"
)

# --- STAŁE KONFIGURACYJNE (Brak magicznych liczb) ---
const DEFAULT_CAMERA_CULL_MASK: int = 4294967293
const CAMERA_LERP_SPEED: float = 15.0
const MIN_ALLOWED_ZOOM_OUT: float = 0.03
const MIN_EFFECTIVE_MAX_ZOOM_IN: float = 1.5
const SLIDER_STEP: float = 0.001

@export_group("Konfiguracja")
@export var level_manager : Map
@export var cell_size : float = 32.0
@export var cell_spacing : float = 4.0
@export var full_view_scaller : float = 4.0

@export_group("Tryb Dewelopera")
## Zaznacz to, aby wyłączyć płaski plik PNG, a włączyć starą, "ciężką"
## kamerę podglądającą prawdziwy fizyczny świat na żywo (np. do testowania chunków).
## W GRZE MOŻESZ TO PRZEŁĄCZAĆ KLAWISZEM!
@export var use_developer_physical_camera: bool = false

@export_group("Statyczna Mapa (PNG)")
## Wewnętrzny wskaźnik na Sprite2D.
var map_sprite: Sprite2D

@export_group("Kolory")
var original_bg_color: Color
@export var current_map_region_color : Color = Color(1.0, 1.0, 1.0, 0.9)
@export var visited_map_region_color : Color = Color(0.6, 0.6, 0.6, 0.8)
@export var discovered_not_visited_color : Color = Color(0.3, 0.3, 0.3, 0.6)
@export var background_color : Color = Color(0.0, 0.0, 0.0, 0.5)
@export var text_color : Color = Color(0.0, 0.0, 0.0, 1.0)

# =========================================================================
# SYSTEM WYMAGAŃ (Ekwipunek Gracza)
# =========================================================================
@export_group("Wymagania Ekwipunku (Przedmioty)")
@export var requires_map_item_for_visibility: bool = false
@export var requires_map_item_for_camera_mode: bool = true
@export var map_item_id: StringName = &"map"

@export var requires_compass_item: bool = true
@export var compass_item_id: StringName = &"compass"

# =========================================================================
# TRYB KAMERY (Open World)
# =========================================================================
@export_group("Tryb Kamery (Live Map)")
@export var use_camera_mode: bool = true
@export var allowed_camera_map_region_types: Array[MapRegion.MapRegionType] = [MapRegion.MapRegionType.OPEN_WORLD]
@export var camera_tint: Color = Color(0.95, 0.95, 1.0, 1.0)
@export var player_marker_color: Color = Color(0.0, 1.0, 0.0, 1.0):
	set(value):
		player_marker_color = value
		if is_instance_valid(_marker_renderer):
			_marker_renderer.player_marker_color = value
			_marker_renderer.queue_redraw()
@export_range(0.0, 1.0) var opacity_preview: float = 0.8
@export_range(0.0, 1.0) var opacity_fullscreen: float = 1.0

@export_subgroup("Znacznik Manualny (Pin)")
@export var allow_manual_marker: bool = true
@export var manual_marker_color: Color = Color(1.0, 0.2, 0.2, 1.0):
	set(value):
		manual_marker_color = value
		if is_instance_valid(_marker_renderer):
			_marker_renderer.manual_marker_color = value
			_marker_renderer.queue_redraw()

@export_subgroup("Interakcja i Płynny Zoom")
@export var allow_panning: bool = true
@export var allow_zooming: bool = true
@export var pan_sensitivity: float = 3.0
@export var zoom_sensitivity: float = 0.05
@export var zoom_preview_default: float = 0.3
@export var auto_zoom_to_fit_fullscreen: bool = true
@export var zoom_fullscreen_default: float = 0.3
@export var zoom_max_in: float = 1.5
@export var zoom_step: float = 0.05

@export_subgroup("Granice Kamery (Limits)")
@export var auto_calculate_bounds: bool = true
@export var bounds_include_undiscovered: bool = false
@export var bounds_padding_px: int = 128

# --- ZMIENNE WEWNĘTRZNE (STAN GRY) ---
var is_map_toggled_large: bool = false
var target_zoom: float = 1.0
var target_camera_pos: Vector2 = Vector2.ZERO
var calculated_fit_zoom: float = 1.0
var calculated_map_center: Vector2 = Vector2.ZERO
var map_world_rect: Rect2 = Rect2()

var is_panning: bool = false
var is_camera_detached: bool = false
var _initial_camera_snapped: bool = false

# Stan znacznika (Pinu) jest własnością osobnego renderera.
var has_manual_marker: bool:
	get:
		return _marker_renderer.has_manual_marker if is_instance_valid(_marker_renderer) else false
	set(value):
		if is_instance_valid(_marker_renderer):
			_marker_renderer.has_manual_marker = value
			_marker_renderer.queue_redraw()

var manual_marker_world_pos: Vector2:
	get:
		return (
			_marker_renderer.manual_marker_world_pos
			if is_instance_valid(_marker_renderer)
			else Vector2.ZERO
		)
	set(value):
		if is_instance_valid(_marker_renderer):
			_marker_renderer.manual_marker_world_pos = value
			_marker_renderer.queue_redraw()

# Cache ekwipunku gracza
var _player_has_map: bool = false
var _player_has_compass: bool = false

# --- WĘZŁY GENEROWANE AUTOMATYCZNIE DLA KAMERY ---
var camera_container: SubViewportContainer
var camera_viewport: SubViewport
var map_camera: Camera2D
var player_marker: MinimapMarkerRendererType
var _marker_renderer: MinimapMarkerRendererType
var _grid_renderer: MinimapGridRendererType
var _map_controller: MinimapMapControllerType
var _camera_bounds_controller: MinimapCameraBoundsControllerType

# --- WĘZŁY INTERFEJSU (UI) ---
var ui_container: Control
var zoom_slider: VSlider
var center_button: Button
var remove_marker_button: Button

func _ready() -> void:
	original_bg_color = background_color
	pivot_offset = size

	# Pobranie stanu z globalnych ustawień na starcie gry
	if "use_developer_camera" in GlobalSettings:
		use_developer_physical_camera = GlobalSettings.use_developer_camera

	_map_controller = MinimapMapControllerType.new()
	_camera_bounds_controller = MinimapCameraBoundsControllerType.new()

	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if not get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.connect(_on_node_removed)
	if not EventBus.game_event_occurred.is_connected(_on_game_event_occurred):
		EventBus.game_event_occurred.connect(_on_game_event_occurred)

	_setup_camera_map()
	_try_find_map()
	call_deferred("_sync_inventory_requirements")

func _exit_tree() -> void:
	if is_inside_tree():
		var scene_tree: SceneTree = get_tree()
		if scene_tree.node_added.is_connected(_on_node_added):
			scene_tree.node_added.disconnect(_on_node_added)
		if scene_tree.node_removed.is_connected(_on_node_removed):
			scene_tree.node_removed.disconnect(_on_node_removed)
	if EventBus.game_event_occurred.is_connected(_on_game_event_occurred):
		EventBus.game_event_occurred.disconnect(_on_game_event_occurred)
	_unbind_map()

## Zwraca maksymalny dozwolony zoom przybliżenia (gwarantuje możliwość przybliżenia nawet gdy w Inspektorze zostało 0.3).
func _get_effective_max_zoom_in() -> float:
	return maxf(zoom_max_in, MIN_EFFECTIVE_MAX_ZOOM_IN)

# --- BUDOWANIE LIVE KAMERY I INTERFEJSU ---
func _setup_camera_map() -> void:
	_grid_renderer = MinimapGridRendererType.new()
	_grid_renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_renderer)
	move_child(_grid_renderer, 0)

	camera_container = SubViewportContainer.new()
	camera_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera_container.stretch = true
	camera_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_container.hide()
	add_child(camera_container)

	camera_viewport = SubViewport.new()
	camera_viewport.transparent_bg = true
	camera_viewport.disable_3d = true
	camera_viewport.gui_disable_input = true
	camera_viewport.audio_listener_enable_2d = false
	camera_viewport.audio_listener_enable_3d = false
	camera_viewport.canvas_cull_mask = DEFAULT_CAMERA_CULL_MASK

	# Tworzymy Sprite2D zawsze, aby móc przełączać w locie
	map_sprite = Sprite2D.new()
	map_sprite.centered = false
	camera_viewport.add_child(map_sprite)
	_map_controller.initialize(map_sprite, use_developer_physical_camera)

	if use_developer_physical_camera:
		camera_viewport.world_2d = get_viewport().world_2d
		map_sprite.hide()
	else:
		camera_viewport.world_2d = World2D.new()
		map_sprite.show()

	camera_container.add_child(camera_viewport)

	map_camera = Camera2D.new()
	camera_viewport.add_child(map_camera)
	map_camera.make_current()

	player_marker = MinimapMarkerRendererType.new()
	player_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_marker.configure(
		map_camera,
		camera_container,
		Callable(self, "_is_camera_mode_active"),
		player_marker_color,
		manual_marker_color
	)
	_marker_renderer = player_marker
	add_child(player_marker)

	ui_container = Control.new()
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_container.hide()
	add_child(ui_container)

	zoom_slider = VSlider.new()
	zoom_slider.min_value = MIN_ALLOWED_ZOOM_OUT
	zoom_slider.max_value = _get_effective_max_zoom_in()
	zoom_slider.step = SLIDER_STEP
	zoom_slider.value_changed.connect(func(val: float):
		if is_map_toggled_large and not is_equal_approx(target_zoom, val):
			is_camera_detached = true
			target_zoom = val
	)
	ui_container.add_child(zoom_slider)

	center_button = Button.new()
	center_button.text = "🎯"
	center_button.tooltip_text = "Wyśrodkuj na graczu"
	center_button.pressed.connect(_on_center_pressed)
	ui_container.add_child(center_button)

	remove_marker_button = Button.new()
	remove_marker_button.text = "❌"
	remove_marker_button.tooltip_text = "Usuń znacznik z mapy"
	remove_marker_button.pressed.connect(_clear_manual_marker)
	remove_marker_button.hide()
	ui_container.add_child(remove_marker_button)

	set_process(true)
	target_zoom = zoom_preview_default
	map_camera.zoom = Vector2(target_zoom, target_zoom)
	_apply_visual_state(false)
	_load_automatic_minimap_data()
	_refresh_grid_renderer()

# --- SYSTEM PRZEŁĄCZANIA W LOCIE (INPUT MAP) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ToggleDevCamera"):
		if "use_developer_camera" in GlobalSettings:
			GlobalSettings.use_developer_camera = not GlobalSettings.use_developer_camera
			GlobalSettings.save_settings()

func _toggle_developer_camera(enable: bool) -> void:
	use_developer_physical_camera = enable
	_map_controller.set_developer_camera_enabled(enable)

	if not is_instance_valid(camera_viewport):
		return

	if use_developer_physical_camera:
		print("Minimapa: Włączono tryb dewelopera (Fizyczna Kamera)")
		camera_viewport.world_2d = get_viewport().world_2d
		if is_instance_valid(map_sprite):
			map_sprite.hide()
	else:
		print("Minimapa: Wyłączono tryb dewelopera (Tryb PNG)")
		camera_viewport.world_2d = World2D.new()
		if is_instance_valid(map_sprite):
			map_sprite.show()
		_load_automatic_minimap_data()

	queue_redraw()
	_refresh_grid_renderer()

func _refresh_grid_renderer() -> void:
	if not is_instance_valid(_grid_renderer):
		return
	_grid_renderer.level_manager = level_manager
	_grid_renderer.cell_size = cell_size
	_grid_renderer.cell_spacing = cell_spacing
	_grid_renderer.is_map_toggled_large = is_map_toggled_large
	_grid_renderer.current_map_region_color = current_map_region_color
	_grid_renderer.visited_map_region_color = visited_map_region_color
	_grid_renderer.discovered_not_visited_color = discovered_not_visited_color
	_grid_renderer.background_color = background_color
	_grid_renderer.original_bg_color = original_bg_color
	_grid_renderer.text_color = text_color
	_grid_renderer.opacity_preview = opacity_preview
	_grid_renderer.opacity_fullscreen = opacity_fullscreen
	_grid_renderer.camera_mode_active = _is_camera_mode_active()
	_grid_renderer.queue_redraw()

## Synchronizuje stan posiadania mapy i kompasu bezpośrednio z ekwipunkiem gracza.
## Gwarantuje działanie znaczników i trybu kamery nawet przed pierwszym sygnałem inventory_changed.
func _sync_inventory_requirements() -> void:
	if not is_inside_tree():
		return
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("get_inventory"):
		var inv: Inventory = player.call("get_inventory") as Inventory
		if inv != null:
			_update_inventory_flags(inv)

func _update_inventory_flags(inv: Inventory) -> void:
	if inv == null:
		return
	var old_map_state: bool = _player_has_map
	var old_compass_state: bool = _player_has_compass

	_player_has_map = inv.get_item_amount(map_item_id) > 0
	_player_has_compass = inv.get_item_amount(compass_item_id) > 0

	if old_compass_state and not _player_has_compass:
		if has_manual_marker:
			_clear_manual_marker()

	if not old_map_state and _player_has_map:
		_initial_camera_snapped = false

	queue_redraw()
	_refresh_grid_renderer()

func _on_game_event_occurred(event_name: String, event_data: Dictionary) -> void:
	if event_name == "inventory_changed":
		var inv: Inventory = event_data.get("inventory") as Inventory
		if inv != null:
			_update_inventory_flags(inv)

func _is_camera_mode_active() -> bool:
	if not use_camera_mode:
		return false
	if requires_map_item_for_camera_mode and not _player_has_map:
		return false
	if is_instance_valid(level_manager) and is_instance_valid(level_manager.current_map_region):
		if "is_mappable" in level_manager.current_map_region and not level_manager.current_map_region.is_mappable:
			return false
		if level_manager.current_map_region.map_region_type in allowed_camera_map_region_types:
			return true
		return false
	return use_camera_mode

func _gui_input(event: InputEvent) -> void:
	if not _is_camera_mode_active() or not is_map_toggled_large:
		return

	if allow_zooming and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_towards_mouse(zoom_sensitivity)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_towards_mouse(-zoom_sensitivity)
			accept_event()

	if allow_panning:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (event as InputEventMouseButton).pressed:
				is_panning = true
				is_camera_detached = true
				target_camera_pos = map_camera.global_position
			else:
				is_panning = false
			accept_event()

		if event is InputEventMouseMotion and is_panning:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			var drag_delta: Vector2 = mm.relative / maxf(0.001, map_camera.zoom.x)
			target_camera_pos -= (drag_delta * pan_sensitivity)
			accept_event()

	if allow_manual_marker and event is InputEventMouseButton:
		var mb_marker: InputEventMouseButton = event as InputEventMouseButton
		if mb_marker.button_index == MOUSE_BUTTON_RIGHT and mb_marker.pressed:
			_sync_inventory_requirements()
			if requires_compass_item and not _player_has_compass:
				print("UI: Nie posiadasz kompasu, by stawiać znaczniki na mapie!")
				return
			_place_manual_marker()
			accept_event()

func _zoom_towards_mouse(amount: float) -> void:
	var old_zoom: float = target_zoom
	var min_z: float = zoom_slider.min_value if is_instance_valid(zoom_slider) else MIN_ALLOWED_ZOOM_OUT
	var max_z: float = _get_effective_max_zoom_in()
	target_zoom = clampf(target_zoom + amount, min_z, max_z)

	if not is_equal_approx(old_zoom, target_zoom):
		is_camera_detached = true
		var mouse_offset: Vector2 = get_local_mouse_position() - (size / 2.0)
		var shift: Vector2 = mouse_offset * ((1.0 / old_zoom) - (1.0 / target_zoom))
		target_camera_pos += shift
		if is_instance_valid(zoom_slider):
			zoom_slider.set_value_no_signal(target_zoom)

func _on_center_pressed() -> void:
	is_camera_detached = false
	if auto_zoom_to_fit_fullscreen:
		target_zoom = calculated_fit_zoom
	else:
		target_zoom = zoom_fullscreen_default
	if is_instance_valid(zoom_slider):
		zoom_slider.set_value_no_signal(target_zoom)

func _place_manual_marker() -> void:
	if not is_instance_valid(map_camera):
		return

	var mouse_local: Vector2 = get_local_mouse_position()
	var center_ui: Vector2 = size / 2.0
	var ui_diff: Vector2 = mouse_local - center_ui
	var world_diff: Vector2 = ui_diff / maxf(0.001, map_camera.zoom.x)

	manual_marker_world_pos = map_camera.get_screen_center_position() + world_diff
	has_manual_marker = true
	if is_instance_valid(remove_marker_button):
		remove_marker_button.show()
	if is_instance_valid(player_marker):
		player_marker.queue_redraw()

func _clear_manual_marker() -> void:
	has_manual_marker = false
	if is_instance_valid(remove_marker_button):
		remove_marker_button.hide()
	if is_instance_valid(player_marker):
		player_marker.queue_redraw()

func _clamp_camera_pos(pos: Vector2) -> Vector2:
	if not auto_calculate_bounds or map_world_rect.size == Vector2.ZERO or not is_instance_valid(map_camera):
		return pos
	return _camera_bounds_controller.clamp_position(pos, size, target_zoom)

func _process(_delta: float) -> void:
	if "use_developer_camera" in GlobalSettings and GlobalSettings.use_developer_camera != use_developer_physical_camera:
		_toggle_developer_camera(GlobalSettings.use_developer_camera)

	if requires_map_item_for_visibility and not _player_has_map:
		hide()
		return
	else:
		show()

	var cam_active: bool = _is_camera_mode_active()

	if not cam_active:
		if camera_container.visible:
			camera_container.hide()
			player_marker.hide()
			ui_container.hide()
		if has_manual_marker:
			_clear_manual_marker()
		queue_redraw()
		return

	if not camera_container.visible:
		camera_container.show()
		player_marker.show()
		if is_map_toggled_large:
			ui_container.show()
		queue_redraw()

	var player: Node2D = get_tree().get_first_node_in_group("Player") as Node2D
	if not is_camera_detached and player != null:
		target_camera_pos = player.global_position
		if not _initial_camera_snapped and is_instance_valid(map_camera):
			map_camera.global_position = target_camera_pos
			_initial_camera_snapped = true

	target_camera_pos = _clamp_camera_pos(target_camera_pos)

	if is_instance_valid(map_camera):
		map_camera.global_position = map_camera.global_position.lerp(target_camera_pos, CAMERA_LERP_SPEED * _delta)
		var current_z: float = lerpf(map_camera.zoom.x, target_zoom, CAMERA_LERP_SPEED * _delta)
		map_camera.zoom = Vector2(current_z, current_z)

	player_marker.queue_redraw()

func _update_camera_limits() -> void:
	if not is_instance_valid(map_camera):
		return

	var effective_max_z: float = _get_effective_max_zoom_in()
	_camera_bounds_controller.calculate_bounds(
		level_manager if auto_calculate_bounds else null,
		bounds_include_undiscovered,
		bounds_padding_px,
		size,
		effective_max_z,
		zoom_fullscreen_default
	)
	map_world_rect = _camera_bounds_controller.world_rect
	calculated_map_center = _camera_bounds_controller.map_center
	calculated_fit_zoom = _camera_bounds_controller.fit_zoom

	if is_instance_valid(zoom_slider):
		zoom_slider.max_value = effective_max_z
		if not auto_calculate_bounds or not is_instance_valid(level_manager) or level_manager.all_map_regions.is_empty():
			zoom_slider.min_value = MIN_ALLOWED_ZOOM_OUT
			return
		if map_world_rect.size != Vector2.ZERO:
			# Gwarantujemy, że zawsze można oddalić mapę do pełnego widoku oraz przybliżyć do detali!
			zoom_slider.min_value = minf(MIN_ALLOWED_ZOOM_OUT, calculated_fit_zoom * 0.5)

#region EVENT-DRIVEN MAP BINDING
func _try_find_map() -> void:
	var map_node: Node = get_tree().get_first_node_in_group("Map")
	if map_node is Map:
		_bind_map(map_node as Map)

func _on_node_added(node: Node) -> void:
	if node is Map:
		_bind_map(node as Map)

func _on_node_removed(node: Node) -> void:
	if node == level_manager:
		_unbind_map()

func _bind_map(new_map: Map) -> void:
	if not is_instance_valid(new_map):
		return
	if level_manager != new_map:
		_unbind_map()
		level_manager = new_map
		_initial_camera_snapped = false
		_map_controller.bind(level_manager, _on_map_state_changed)
		_sync_inventory_requirements()
		_update_camera_limits()
		_clear_manual_marker()
		queue_redraw()
		_refresh_grid_renderer()

func _load_automatic_minimap_data() -> void:
	_map_controller.load_automatic_minimap_data()

func _unbind_map() -> void:
	_map_controller.unbind()
	level_manager = null
	_clear_manual_marker()
	queue_redraw()
	_refresh_grid_renderer()
#endregion

func toggle_large_map(is_large: bool) -> void:
	is_map_toggled_large = is_large
	is_camera_detached = false
	is_panning = false

	if is_large:
		_sync_inventory_requirements()
		scale = Vector2(full_view_scaller, full_view_scaller)
		clip_contents = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		if has_meta("original_mouse_filter"):
			set_meta("original_mouse_filter", Control.MOUSE_FILTER_STOP)
		if _is_camera_mode_active():
			ui_container.show()
			_update_ui_layout()
	else:
		scale = Vector2(1.0, 1.0)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if has_meta("original_mouse_filter"):
			set_meta("original_mouse_filter", Control.MOUSE_FILTER_IGNORE)
		ui_container.hide()

	_apply_visual_state(is_large)
	queue_redraw()
	_refresh_grid_renderer()

func _update_ui_layout() -> void:
	if not is_instance_valid(ui_container):
		return

	ui_container.size = size * full_view_scaller
	ui_container.scale = Vector2(1.0 / full_view_scaller, 1.0 / full_view_scaller)

	var w: float = ui_container.size.x
	var h: float = ui_container.size.y

	zoom_slider.size = Vector2(30.0, h * 0.4)
	zoom_slider.position = Vector2(w - 60.0, h * 0.2)

	center_button.size = Vector2(45.0, 45.0)
	center_button.position = Vector2(w - 67.0, (h * 0.2) + zoom_slider.size.y + 15.0)

	remove_marker_button.size = Vector2(45.0, 45.0)
	remove_marker_button.position = Vector2(w - 67.0, (h * 0.2) + zoom_slider.size.y + 15.0 + 50.0)

func _apply_visual_state(is_large: bool) -> void:
	var current_opacity: float = opacity_fullscreen if is_large else opacity_preview
	if is_instance_valid(camera_container):
		camera_container.modulate = Color(camera_tint.r, camera_tint.g, camera_tint.b, current_opacity)

	if is_large:
		_update_camera_limits()
		if auto_zoom_to_fit_fullscreen:
			target_zoom = calculated_fit_zoom
		else:
			target_zoom = zoom_fullscreen_default

		if is_instance_valid(zoom_slider):
			zoom_slider.set_value_no_signal(target_zoom)
	else:
		target_zoom = zoom_preview_default

func _on_map_state_changed(_map_region = null) -> void:
	_sync_inventory_requirements()
	if not _is_camera_mode_active():
		_clear_manual_marker()
	_update_camera_limits()
	_load_automatic_minimap_data()
	queue_redraw()
	_refresh_grid_renderer()
