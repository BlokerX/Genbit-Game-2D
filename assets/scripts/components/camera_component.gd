extends Camera2D
class_name CameraComponent

@export_group("Podążanie (Follow)")
@export var enable_aim_peek: bool = false
@export var follow_speed: float = 8.0
@export var look_ahead_factor: float = 0.25
@export var max_look_ahead: float = 150.0

@export_group("Martwa Strefa (Dead Zone)")
@export var use_dead_zone: bool = true
@export var dead_zone_size: Vector2 = Vector2(250.0, 150.0)

@export_group("Dynamiczny Zoom")
@export var default_zoom: Vector2 = Vector2(1.0, 1.0)
@export var arena_zoom: Vector2 = Vector2(0.8, 0.8)
@export var zoom_speed: float = 3.0

@export_group("Wstrząsy (Screen Shake)")
@export var max_shake_offset: Vector2 = Vector2(30.0, 30.0)
@export var shake_decay_rate: float = 5.0

# --- REFERENCJE I ZMIENNE WEWNĘTRZNE ---
@onready var player: PlayerCharacter = get_parent() as PlayerCharacter
var level_manager: Map = null
var current_room: Room = null

var _trauma: float = 0.0
var _focal_point: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = default_zoom

# Zmienne do Magii Przejść
var _was_sliding: bool = false 
var _slide_start_offset: Vector2 = Vector2.ZERO
var _cam_start_pos: Vector2 = Vector2.ZERO
var _cam_end_pos: Vector2 = Vector2.ZERO

# Magia usuwająca skok ładowania pierwszej sceny
var _is_first_frame: bool = true 

func _ready() -> void:
	top_level = true 
	
	process_mode = Node.PROCESS_MODE_ALWAYS 
	process_physics_priority = 100
	set_process(false) 
	
	global_position = player.global_position
	_focal_point = player.global_position
	zoom = default_zoom
	_target_zoom = default_zoom
	
	make_current() 
	
	_try_find_map()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	
	# 1. SYSTEM ZOOMA (Działa zawsze)
	if is_instance_valid(current_room):
		if current_room.room_type == Room.RoomType.BOSS or current_room.room_type == Room.RoomType.ARENA:
			_target_zoom = arena_zoom
		else:
			_target_zoom = default_zoom
	zoom = zoom.lerp(_target_zoom, zoom_speed * delta)
	
	var is_transitioning = player.process_mode == Node.PROCESS_MODE_DISABLED
	var slide_offset = Vector2.ZERO
	if is_instance_valid(current_room):
		slide_offset = current_room.position
		
	var is_sliding = slide_offset.length_squared() > 1.0
	
	# =========================================================
	# MAGIA PRZEJŚĆ - ANIMACJA SLIDE (Gdy pokój fizycznie jedzie)
	# =========================================================
	if is_transitioning and is_sliding:
		if not _was_sliding:
			_was_sliding = true
			_cam_start_pos = global_position
			_slide_start_offset = slide_offset
			
			var future_player_pos = player.global_position - slide_offset
			
			if not current_room.camera_follows_player:
				_cam_end_pos = current_room.size_px / 2.0
			else:
				_cam_end_pos = future_player_pos
				
			_cam_end_pos = _get_future_clamped_target(_cam_end_pos)
			_focal_point = future_player_pos
		
		var progress = 1.0
		if _slide_start_offset.length_squared() > 0:
			progress = 1.0 - (slide_offset.length() / _slide_start_offset.length())
			
		global_position = _cam_start_pos.lerp(_cam_end_pos, progress)
		return 
		
	elif _was_sliding:
		_was_sliding = false
		_focal_point = player.global_position
	# =========================================================

	var desired_pos = Vector2.ZERO
	var is_static_room = false
	
	# 2. OBLICZANIE DOCELOWEJ POZYCJI DLA NORMALNEJ GRY ORAZ FADE
	if is_instance_valid(current_room):
		if not current_room.camera_follows_player:
			is_static_room = true
			desired_pos = current_room.global_position + (current_room.size_px / 2.0)
			_focal_point = player.global_position
		else:
			_update_focal_point()
			desired_pos = _calculate_dynamic_target()
	else:
		_update_focal_point()
		desired_pos = _calculate_dynamic_target()
	
	# 3. ZACISKANIE GRANIC (Działa dla ruchu i dla natychmiastowego teleportu przy FADE)
	desired_pos = _clamp_to_room_bounds(desired_pos)
	
	# =========================================================
	# 4. APLIKOWANIE RUCHU KAMERY (Magia ukrywania skoków)
	# =========================================================
	if _is_first_frame or (is_transitioning and not is_sliding):
		# TWARDY SNAP: Uruchamiany TYLKO przy pierwszej klatce ładowania gry 
		# ALBO podczas trwania ściemnienia FADE.
		# W tym momencie przerywamy jakiekolwiek wygładzanie (lerp) i teleportujemy 
		# kamerę na odpowiednie miejsce w cieniu/na ekranie ładowania.
		global_position = desired_pos
		_is_first_frame = false
	elif is_static_room:
		if global_position.distance_to(desired_pos) < 1.0:
			global_position = desired_pos
		else:
			global_position = global_position.lerp(desired_pos, follow_speed * delta)
	else:
		global_position = global_position.lerp(desired_pos, follow_speed * delta)
		
	# 5. APLIKOWANIE WSTRZĄSÓW (Screen Shake)
	_apply_screen_shake(delta)

#region Obliczanie Celu i Granic

func _get_future_clamped_target(target_pos: Vector2) -> Vector2:
	if not is_instance_valid(current_room): return target_pos
	
	var viewport_size = get_viewport_rect().size / _target_zoom
	var half_screen = viewport_size / 2.0
	var room_size = current_room.size_px
	
	var min_x = half_screen.x
	var max_x = room_size.x - half_screen.x
	var min_y = half_screen.y
	var max_y = room_size.y - half_screen.y
	
	if room_size.x < viewport_size.x:
		target_pos.x = room_size.x / 2.0
	else:
		target_pos.x = clamp(target_pos.x, min_x, max_x)
		
	if room_size.y < viewport_size.y:
		target_pos.y = room_size.y / 2.0
	else:
		target_pos.y = clamp(target_pos.y, min_y, max_y)
		
	return target_pos

func _update_focal_point() -> void:
	if not use_dead_zone:
		_focal_point = player.global_position
		return
		
	var extents = dead_zone_size / 2.0
	var diff = player.global_position - _focal_point
	
	if diff.x > extents.x:
		_focal_point.x += diff.x - extents.x
	elif diff.x < -extents.x:
		_focal_point.x += diff.x + extents.x
		
	if diff.y > extents.y:
		_focal_point.y += diff.y - extents.y
	elif diff.y < -extents.y:
		_focal_point.y += diff.y + extents.y

func _calculate_dynamic_target() -> Vector2:
	var aim_offset = Vector2.ZERO
	
	if enable_aim_peek and player.aim_controller and player.aim_controller.aim_scanner:
		var aim_target = player.aim_controller.aim_scanner.target_position
		aim_offset = aim_target * look_ahead_factor
		aim_offset = aim_offset.limit_length(max_look_ahead)
		
	return _focal_point + aim_offset

func _clamp_to_room_bounds(target_pos: Vector2) -> Vector2:
	if not is_instance_valid(current_room): return target_pos
	
	var viewport_size = get_viewport_rect().size / zoom
	var half_screen = viewport_size / 2.0
	
	var room_pos = current_room.global_position
	var room_size = current_room.size_px
	
	var min_x = room_pos.x + half_screen.x
	var max_x = room_pos.x + room_size.x - half_screen.x
	var min_y = room_pos.y + half_screen.y
	var max_y = room_pos.y + room_size.y - half_screen.y
	
	if room_size.x < viewport_size.x:
		target_pos.x = room_pos.x + room_size.x / 2.0
	else:
		target_pos.x = clamp(target_pos.x, min_x, max_x)
		
	if room_size.y < viewport_size.y:
		target_pos.y = room_pos.y + room_size.y / 2.0
	else:
		target_pos.y = clamp(target_pos.y, min_y, max_y)
		
	return target_pos

#endregion

#region Event-Driven Map Binding

func _try_find_map() -> void:
	var map_node = get_tree().get_first_node_in_group("Map")
	if map_node is Map: _bind_map(map_node)

func _on_node_added(node: Node) -> void:
	if node is Map: _bind_map(node)

func _on_node_removed(node: Node) -> void:
	if node == level_manager: _unbind_map()

func _bind_map(new_map: Map) -> void:
	if level_manager == new_map: return
	if level_manager != null: _unbind_map()
		
	level_manager = new_map
	if not level_manager.room_changed.is_connected(_on_room_changed):
		level_manager.room_changed.connect(_on_room_changed)
		
	if level_manager.current_room:
		_on_room_changed(level_manager.current_room)

func _unbind_map() -> void:
	if is_instance_valid(level_manager) and level_manager.room_changed.is_connected(_on_room_changed):
		level_manager.room_changed.disconnect(_on_room_changed)
	level_manager = null
	current_room = null

func _on_room_changed(new_room: Room) -> void:
	current_room = new_room

#endregion

#region System Wstrząsów (Screen Shake / Trauma)

func add_trauma(amount: float) -> void:
	_trauma = clamp(_trauma + amount, 0.0, 1.0)

func _apply_screen_shake(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = max(_trauma - shake_decay_rate * delta, 0.0)
		var shake_amount = _trauma * _trauma 
		
		offset.x = max_shake_offset.x * shake_amount * randf_range(-1.0, 1.0)
		offset.y = max_shake_offset.y * shake_amount * randf_range(-1.0, 1.0)
	else:
		offset = Vector2.ZERO

#endregion
