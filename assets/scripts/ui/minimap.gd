extends Control
class_name Minimap

#@export_group("Ikony Pokoi")
#@export var icon_treasure : Texture2D
#@export var icon_shop : Texture2D
#@export var icon_boss : Texture2D

@export_group("Konfiguracja")
@export var level_manager : Map
@export var cell_size : float = 32.0
@export var cell_spacing : float = 4.0
@export var full_view_scaller : float = 4

@export_group("Kolory")
var original_bg_color: Color
@export var current_room_color : Color = Color(1.0, 1.0, 1.0, 0.9)
@export var visited_room_color : Color = Color(0.6, 0.6, 0.6, 0.8) 
@export var discovered_not_visited_color : Color = Color(0.3, 0.3, 0.3, 0.6) 
@export var background_color : Color = Color(0.0, 0.0, 0.0, 0.5)
@export var text_color : Color = Color(0.0, 0.0, 0.0, 1.0) 

# =========================================================================
# SYSTEM WYMAGAŃ (Ekwipunek Gracza)
# =========================================================================
@export_group("Wymagania Ekwipunku (Przedmioty)")
## Czy gracz MUSI mieć w ekwipunku przedmiot "Mapa", aby móc otworzyć i widzieć Minimapę?
@export var requires_map_item_for_visibility: bool = false
## Czy gracz MUSI mieć przedmiot "Mapa", aby korzystać z zaawansowanej kamery Open World?
@export var requires_map_item_for_camera_mode: bool = true
## Dokładne ID przedmiotu z pliku .tres, np. "map"
@export var map_item_id: StringName = &"map"

## Czy gracz MUSI mieć w ekwipunku kompas, by stawiać na mapie własne znaczniki (PPM)?
@export var requires_compass_item: bool = true
## Dokładne ID kompasu z pliku .tres, np. "compass"
@export var compass_item_id: StringName = &"compass"

# =========================================================================
# TRYB KAMERY (Open World)
# =========================================================================
@export_group("Tryb Kamery (Live Map)")
## Jeśli włączone (i gracz ma mapę), mapa będzie renderowana przez fizyczną kamerę, ALE TYLKO w dozwolonych typach pokoi.
@export var use_camera_mode: bool = true
## Lista typów pokoi, w których wolno używać "Live Mapy". W innych mapa wróci do trybu kafelkowego.
@export var allowed_camera_room_types: Array[Room.RoomType] = [Room.RoomType.OPEN_WORLD]
@export var camera_tint: Color = Color(0.95, 0.95, 1.0, 1.0)
@export var player_marker_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export_range(0.0, 1.0) var opacity_preview: float = 0.8
@export_range(0.0, 1.0) var opacity_fullscreen: float = 1.0

@export_subgroup("Znacznik Manualny (Pin)")
@export var allow_manual_marker: bool = true
## Kolor pinu stawianego przez gracza prawym przyciskiem myszy oraz strzałki nawigacyjnej kompasu.
@export var manual_marker_color: Color = Color(1.0, 0.2, 0.2, 1.0) 

@export_subgroup("Interakcja i Płynny Zoom")
@export var allow_panning: bool = true
@export var allow_zooming: bool = true
## Czułość przeciągania mapy myszką (wyższa = szybsze ruszanie ręką)
@export var pan_sensitivity: float = 3.0
## Czułość kółka myszy przy przybliżaniu/oddalaniu
@export var zoom_sensitivity: float = 0.05
## Powiększenie dla małej mapki w rogu ekranu (0.3 = w miarę blisko)
@export var zoom_preview_default: float = 0.3
## Jeśli włączone, duża mapa ZIGNORUJE 'zoom_fullscreen_default' i sama matematycznie obliczy idealny zoom.
@export var auto_zoom_to_fit_fullscreen: bool = true
## Domyślny zoom na dużym ekranie (używany np. po powrocie do środka)
@export var zoom_fullscreen_default: float = 0.3
## MAKSYMALNE PRZYBLIŻENIE obrazu, z jakiego gracz może korzystać (1.0 = rozmiar naturalny postaci)
@export var zoom_max_in: float = 0.3
@export var zoom_step: float = 0.05

@export_subgroup("Granice Kamery (Limits)")
## Jeśli włączone, skrypt skanuje wszystkie wygenerowane pokoje, by uciąć pustą "czarną przestrzeń" wokół wyspy.
@export var auto_calculate_bounds: bool = true
## Czy auto-zoom ma obejmować przestrzenie dla pokoi, których gracz jeszcze nie odkrył? (Odznacz dla Lochów)
@export var bounds_include_undiscovered: bool = false
## Piksele marginesu dodawane do krawędzi kamery (żeby ekran nie ucinał krawędzi mapy idealnie przy wodzie)
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

# Stan znacznika (Pinu)
var has_manual_marker: bool = false
var manual_marker_world_pos: Vector2 = Vector2.ZERO

# Cache ekwipunku gracza (do optymalizacji wywołań w czasie rzeczywistym)
var _player_has_map: bool = false
var _player_has_compass: bool = false

# --- WĘZŁY GENEROWANE AUTOMATYCZNIE DLA KAMERY ---
var camera_container: SubViewportContainer
var camera_viewport: SubViewport
var map_camera: Camera2D
var player_marker: Control

# --- WĘZŁY INTERFEJSU (UI) ---
var ui_container: Control
var zoom_slider: VSlider
var center_button: Button
var remove_marker_button: Button

func _ready() -> void:
	original_bg_color = background_color
	pivot_offset = size
	
	_try_find_map()
	
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	# Podpięcie pod globalny EventBus (Błyskawiczne odświeżanie plecaka bez obciążania pętli Process)
	EventBus.game_event_occurred.connect(_on_game_event_occurred)
	
	_setup_camera_map()

# --- BUDOWANIE LIVE KAMERY I INTERFEJSU ---
func _setup_camera_map() -> void:
	# 1. Główny Kontener Ekranu Mapy (Rozszerzany na cały element)
	camera_container = SubViewportContainer.new()
	camera_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera_container.stretch = true
	camera_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_container.hide() 
	add_child(camera_container)
	
	# 2. Viewport (Magia klonująca prawdziwy świat gry w locie)
	camera_viewport = SubViewport.new()
	camera_viewport.transparent_bg = true
	camera_viewport.disable_3d = true
	camera_viewport.gui_disable_input = true
	camera_viewport.audio_listener_enable_2d = false
	camera_viewport.audio_listener_enable_3d = false
	camera_viewport.world_2d = get_viewport().world_2d
	camera_container.add_child(camera_viewport)
	
	# 3. Dodatkowa Druga Kamera (Śledząca niezależnie od kamery głównej gry)
	map_camera = Camera2D.new()
	camera_viewport.add_child(map_camera)
	map_camera.make_current() 
	
	# 4. Płótno na kropkę gracza i znacznik
	player_marker = Control.new()
	player_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_marker.draw.connect(_on_player_marker_draw)
	add_child(player_marker)
	
	# 5. Interfejs z Genshin Impact (Slider + Przycisk Powrotu)
	ui_container = Control.new()
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_container.hide()
	add_child(ui_container)
	
	zoom_slider = VSlider.new()
	zoom_slider.min_value = 0.01 
	zoom_slider.max_value = zoom_max_in
	zoom_slider.step = 0.001 
	zoom_slider.value_changed.connect(func(val): 
		if is_map_toggled_large:
			target_zoom = val
	)
	ui_container.add_child(zoom_slider)
	
	center_button = Button.new()
	center_button.text = "🎯"
	center_button.tooltip_text = "Wyśrodkuj na graczu"
	center_button.pressed.connect(_on_center_pressed)
	ui_container.add_child(center_button)
	
	# Guzik usuwania postawionej przez nas flagi na mapie
	remove_marker_button = Button.new()
	remove_marker_button.text = "📍"
	remove_marker_button.tooltip_text = "Usuń znacznik z mapy"
	remove_marker_button.pressed.connect(_clear_manual_marker)
	remove_marker_button.hide() 
	ui_container.add_child(remove_marker_button)
	
	set_process(true)
	
	target_zoom = zoom_preview_default
	map_camera.zoom = Vector2(target_zoom, target_zoom)
	_apply_visual_state(false)


# =========================================================================
# SYSTEM SPRAWDZANIA EKWIPUNKU Z PAMIĘCIĄ PODRĘCZNĄ O(1)
# =========================================================================

## Funkcja wywoływana za każdym razem, gdy ekwipunek się przebuduje (lub na starcie gry).
## Dzięki temu skrypt Minimapy wykonuje matematykę TYLKO WTEDY, gdy wyrzucisz/podniesiesz jakiś przedmiot.
func _on_game_event_occurred(event_name: String, event_data: Dictionary) -> void:
	if event_name == "inventory_changed":
		var inv: Inventory = event_data.get("inventory")
		if inv != null:
			# Pytamy klasę inventory (która korzysta ze słowników Dictionary cache!) o posiadane przedmioty
			# Czas złożoności to zaledwie O(1).
			var old_map_state = _player_has_map
			var old_compass_state = _player_has_compass
			
			_player_has_map = inv.get_item_amount(map_item_id) > 0
			_player_has_compass = inv.get_item_amount(compass_item_id) > 0
			
			# REAKCJA: Jeśli straciliśmy kompas (wcześniej był, a teraz nie ma), automatycznie zdejmujemy znacznik
			if old_compass_state and not _player_has_compass:
				if has_manual_marker:
					_clear_manual_marker()
					
			# REAKCJA: Jeśli zyskaliśmy mapę, musimy wywołać przerysowanie i _initial_camera_snapped
			if not old_map_state and _player_has_map:
				_initial_camera_snapped = false 
				queue_redraw()

## Decyduje, czy aktualnie znajdujemy się w pokoju, który wspiera Live Kamerę 
## ORAZ czy gracz posiada fizycznie mapę (jeśli jest wymagana)
func _is_camera_mode_active() -> bool:
	if not use_camera_mode: return false
	
	# Jeśli wymagamy mapy, by mieć ładną zaawansowaną kamerę, sprawdzamy zoptymalizowaną zmienną bool!
	if requires_map_item_for_camera_mode and not _player_has_map:
		return false
	
	if is_instance_valid(level_manager) and is_instance_valid(level_manager.current_room):
		if level_manager.current_room.room_type in allowed_camera_room_types:
			return true
		return false
		
	return use_camera_mode


# =========================================================================
# INTERAKCJE I MATEMATYKA KAMERY
# =========================================================================

func _gui_input(event: InputEvent) -> void:
	if not _is_camera_mode_active() or not is_map_toggled_large: return
	
	# 1. Scrollowanie (Zooming płynnie celujący w myszkę)
	if allow_zooming and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_towards_mouse(zoom_sensitivity)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_towards_mouse(-zoom_sensitivity)
			accept_event()
			
	# 2. Przeciąganie Mapy (Panning po kliknięciu Lewym Przyciskiem Myszy)
	if allow_panning:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_panning = true
				is_camera_detached = true 
				target_camera_pos = map_camera.global_position
			else:
				is_panning = false
			accept_event()
			
		if event is InputEventMouseMotion and is_panning:
			var drag_delta = event.relative / (map_camera.zoom.x * full_view_scaller)
			target_camera_pos -= (drag_delta * pan_sensitivity)
			accept_event()

	# 3. Wstawianie ręcznego znacznika (Prawy Przycisk Myszy + Wymagany Kompas)
	if allow_manual_marker and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if requires_compass_item and not _player_has_compass:
				print("UI: Nie posiadasz kompasu, by stawiać znaczniki na mapie!")
				return
				
			_place_manual_marker()
			accept_event()

## Przybliża dokładnie w to miejsce, gdzie aktualnie znajduje się kursor myszy (Jak np. w Google Maps)
func _zoom_towards_mouse(amount: float) -> void:
	var old_zoom = target_zoom
	target_zoom = clamp(target_zoom + amount, zoom_slider.min_value, zoom_max_in)
	
	if old_zoom != target_zoom:
		is_camera_detached = true
		var mouse_offset = get_local_mouse_position() - (size / 2.0)
		# Przesuwamy matematyczny cel kamery tak, by punkt pod myszką został stabilnie w miejscu.
		var shift = mouse_offset * ((1.0 / old_zoom) - (1.0 / target_zoom))
		target_camera_pos += shift
		zoom_slider.value = target_zoom

## Resetuje kamerę z powrotem pod bieżącą pozycję gracza
func _on_center_pressed() -> void:
	is_camera_detached = false 
	if auto_zoom_to_fit_fullscreen:
		target_zoom = calculated_fit_zoom
	else:
		target_zoom = zoom_fullscreen_default
	zoom_slider.value = target_zoom

# --- SYSTEM ZNACZNIKÓW (WAYPOINT) ---
func _place_manual_marker() -> void:
	if not is_instance_valid(map_camera): return
	
	var mouse_local = get_local_mouse_position()
	var center_ui = size / 2.0
	var ui_diff = mouse_local - center_ui
	
	# Zamieniamy fizyczne kliknięcie na ekranie na matematyczne współrzędne prawdziwego świata gry.
	var world_diff = ui_diff / map_camera.zoom.x
	manual_marker_world_pos = map_camera.get_screen_center_position() + world_diff
	
	has_manual_marker = true
	remove_marker_button.show()
	player_marker.queue_redraw()

func _clear_manual_marker() -> void:
	has_manual_marker = false
	if is_instance_valid(remove_marker_button):
		remove_marker_button.hide()
	if is_instance_valid(player_marker):
		player_marker.queue_redraw()


# =========================================================================
# GŁÓWNA PĘTLA ZARZĄDZANIA WIZUALIAMI
# =========================================================================

# --- MATEMATYCZNY LIMIT KAMERY ---
## Twarde ograniczenie kamery, żeby po przesunięciu mapy w bok nie wlecieć w czarną pustkę
func _clamp_camera_pos(pos: Vector2) -> Vector2:
	if not auto_calculate_bounds or map_world_rect.size == Vector2.ZERO or not is_instance_valid(map_camera):
		return pos
		
	var half_screen = (size / 2.0) / target_zoom
	var min_x = map_world_rect.position.x + half_screen.x
	var max_x = map_world_rect.end.x - half_screen.x
	var min_y = map_world_rect.position.y + half_screen.y
	var max_y = map_world_rect.end.y - half_screen.y
	
	var clamped = pos
	
	if min_x > max_x:
		clamped.x = calculated_map_center.x
	else:
		clamped.x = clamp(pos.x, min_x, max_x)
		
	if min_y > max_y:
		clamped.y = calculated_map_center.y
	else:
		clamped.y = clamp(pos.y, min_y, max_y)
		
	return clamped

func _process(_delta: float) -> void:
	# --- TARCZA WIDOCZNOŚCI ---
	# Jeśli cała minimapa ma być ukryta ze względu na brak "Papierowej Mapy" w plecaku:
	if requires_map_item_for_visibility and not _player_has_map:
		hide()
		return
	else:
		show()

	# Sprawdzamy czy powinniśmy używać zaawansowanego renderu
	var cam_active = _is_camera_mode_active()
	
	if not cam_active:
		if camera_container.visible:
			camera_container.hide()
			player_marker.hide()
			ui_container.hide()
			
			# AUTOMATYCZNE CZYSZCZENIE ZNACZNIKA gdy gracz traci mapę lub wchodzi do lochu
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
		
	var player = get_tree().get_first_node_in_group("Player")
	
	# Śledzenie Gracza: Kamera płynnie dogania naszą postać (chyba że sami ją pociągnęliśmy myszką)
	if not is_camera_detached and player:
		target_camera_pos = player.global_position
		
		# W pierwszej klatce po wczytaniu teleportujemy obraz od razu, by uniknąć dzikiego skoku z nieba.
		if not _initial_camera_snapped and is_instance_valid(map_camera):
			map_camera.global_position = target_camera_pos
			_initial_camera_snapped = true

	target_camera_pos = _clamp_camera_pos(target_camera_pos)
		
	# Interpolacja LERP (Miękkie docieranie kamery do wyliczonego wyżej celu)
	if is_instance_valid(map_camera):
		map_camera.global_position = map_camera.global_position.lerp(target_camera_pos, 15.0 * _delta)
		var current_z = lerp(map_camera.zoom.x, target_zoom, 15.0 * _delta)
		map_camera.zoom = Vector2(current_z, current_z)
			
	player_marker.queue_redraw() 

# Rysowanie obiektów pomocniczych (Kropka Gracza i Piny) nad polem kamery
func _on_player_marker_draw() -> void:
	if not _is_camera_mode_active() or not camera_container.visible: return
	if not is_instance_valid(map_camera): return
	
	var cam_center = map_camera.get_screen_center_position()
	var center_ui = size / 2.0
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var diff = player.global_position - cam_center
		var draw_pos = center_ui + (diff * map_camera.zoom.x)
		player_marker.draw_circle(draw_pos, 4.0, player_marker_color)
		player_marker.draw_circle(draw_pos, 6.0, Color(0, 0, 0, 0.8), false, 2.0)
		
	# --- RYSOWANIE ZNACZNIKA (PIN LUB KOMPAS) ---
	if has_manual_marker:
		var m_diff = manual_marker_world_pos - cam_center
		var m_draw_pos = center_ui + (m_diff * map_camera.zoom.x)
		
		# Jeśli nasz postawiony Pin wylądował poza ekranem
		var is_offscreen = m_draw_pos.x < 0 or m_draw_pos.y < 0 or m_draw_pos.x > size.x or m_draw_pos.y > size.y
		
		if is_offscreen:
			# Rysujemy dynamiczny Kompas, wskazujący gdzie znajduje się Pin!
			var margin = 15.0
			var half_w = center_ui.x - margin
			var half_h = center_ui.y - margin
			
			var dir = (m_draw_pos - center_ui).normalized()
			
			var t_x = INF
			if abs(dir.x) > 0.0001: t_x = half_w / abs(dir.x)
			
			var t_y = INF
			if abs(dir.y) > 0.0001: t_y = half_h / abs(dir.y)
			
			var t = min(t_x, t_y)
			var clamped_pos = center_ui + dir * t
			
			# Grot Strzałki (Współrzędne)
			var tip = clamped_pos
			var left = clamped_pos - dir * 12.0 + dir.orthogonal() * 6.0
			var right = clamped_pos - dir * 12.0 - dir.orthogonal() * 6.0
			
			var points = PackedVector2Array([tip, left, right])
			var colors = PackedColorArray([manual_marker_color, manual_marker_color, manual_marker_color])
			
			player_marker.draw_polygon(points, colors)
			player_marker.draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.BLACK, 1.5)
		else:
			# Rysujemy klasyczny Pin (Znajduje się w zasięgu naszego wzroku)
			player_marker.draw_line(m_draw_pos, m_draw_pos + Vector2(0, 12), Color(0,0,0,0.8), 2.0)
			player_marker.draw_line(m_draw_pos, m_draw_pos + Vector2(0, 12), manual_marker_color, 1.0)
			player_marker.draw_circle(m_draw_pos, 4.5, manual_marker_color)
			player_marker.draw_circle(m_draw_pos, 6.5, Color(0, 0, 0, 0.8), false, 2.0)


# =========================================================================
# OBLICZANIE GRANIC FIZYCZNYCH CAŁEJ MAPY
# =========================================================================

func _update_camera_limits() -> void:
	if not is_instance_valid(map_camera): return
	
	if not auto_calculate_bounds or not level_manager or level_manager.all_rooms.is_empty():
		map_world_rect = Rect2()
		calculated_fit_zoom = zoom_fullscreen_default
		if zoom_slider: zoom_slider.min_value = 0.01
		return
		
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	var rooms_found = false
	
	var rooms_to_scan = level_manager.all_rooms if bounds_include_undiscovered else level_manager.discovered_rooms
	if rooms_to_scan.is_empty() and not level_manager.discovered_rooms.is_empty():
		rooms_to_scan = level_manager.discovered_rooms 
	
	# Pętla skanująca wszystkie instancje pokoi (Room), upewniając się, że kamera ich nie opuści.
	for room in rooms_to_scan:
		if is_instance_valid(room):
			rooms_found = true
			var r_pos = room.global_position
			var r_size = room.size_px if "size_px" in room else Vector2(1920, 1080)
			
			min_x = min(min_x, r_pos.x)
			min_y = min(min_y, r_pos.y)
			max_x = max(max_x, r_pos.x + r_size.x)
			max_y = max(max_y, r_pos.y + r_size.y)
			
	if rooms_found:
		var left = int(min_x) - bounds_padding_px
		var top = int(min_y) - bounds_padding_px
		var right = int(max_x) + bounds_padding_px
		var bottom = int(max_y) + bounds_padding_px
		
		map_world_rect = Rect2(left, top, right - left, bottom - top)
		calculated_map_center = Vector2(left + right, top + bottom) / 2.0
		
		var map_w = map_world_rect.size.x
		var map_h = map_world_rect.size.y
		
		if map_w > 0 and map_h > 0:
			var z_x = size.x / map_w
			var z_y = size.y / map_h
			calculated_fit_zoom = min(min(z_x, z_y), zoom_max_in)
			
			# Dynamiczna blokada Suwaka - gwarantuje niemożliwość odjechania poza render świata
			if auto_zoom_to_fit_fullscreen and is_instance_valid(zoom_slider):
				zoom_slider.min_value = min(calculated_fit_zoom, zoom_slider.max_value)


#region EVENT-DRIVEN MAP BINDING
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
	_initial_camera_snapped = false 
	
	if not level_manager.room_changed.is_connected(_on_map_state_changed):
		level_manager.room_changed.connect(_on_map_state_changed)
	if not level_manager.map_updated.is_connected(_on_map_state_changed):
		level_manager.map_updated.connect(_on_map_state_changed)
	
	_update_camera_limits()
	
	# Usunięcie starych punktów Pinu po teleportacji do nowej krainy
	_clear_manual_marker()
	queue_redraw()

func _unbind_map() -> void:
	if is_instance_valid(level_manager):
		if level_manager.room_changed.is_connected(_on_map_state_changed):
			level_manager.room_changed.disconnect(_on_map_state_changed)
		if level_manager.map_updated.is_connected(_on_map_state_changed):
			level_manager.map_updated.disconnect(_on_map_state_changed)
	level_manager = null
	
	_clear_manual_marker()
	queue_redraw()
#endregion


# =========================================================================
# ZARZĄDZANIE EKRANEM I KLAWISZEM TAB
# =========================================================================

func toggle_large_map(is_large: bool) -> void:
	is_map_toggled_large = is_large
	is_camera_detached = false 
	
	if is_large:
		scale = Vector2(full_view_scaller, full_view_scaller)
		clip_contents = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		if _is_camera_mode_active():
			ui_container.show()
			_update_ui_layout()
	else:
		scale = Vector2(1.0, 1.0)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE 
		ui_container.hide()
		
	_apply_visual_state(is_large)
	queue_redraw()

func _update_ui_layout() -> void:
	if not is_instance_valid(ui_container): return
	
	ui_container.size = size * full_view_scaller
	ui_container.scale = Vector2(1.0 / full_view_scaller, 1.0 / full_view_scaller)
	
	var w = ui_container.size.x
	var h = ui_container.size.y
	
	zoom_slider.size = Vector2(30, h * 0.4)
	zoom_slider.position = Vector2(w - 60, h * 0.2)
	
	center_button.size = Vector2(45, 45)
	center_button.position = Vector2(w - 67, (h * 0.2) + zoom_slider.size.y + 15)
	
	remove_marker_button.size = Vector2(45, 45)
	remove_marker_button.position = Vector2(w - 67, (h * 0.2) + zoom_slider.size.y + 15 + 50)

func _apply_visual_state(is_large: bool) -> void:
	var current_opacity = opacity_fullscreen if is_large else opacity_preview
	
	if is_instance_valid(camera_container):
		camera_container.modulate = Color(camera_tint.r, camera_tint.g, camera_tint.b, current_opacity)
	
	if is_large:
		_update_camera_limits() 
		if auto_zoom_to_fit_fullscreen:
			target_zoom = calculated_fit_zoom
		else:
			target_zoom = zoom_fullscreen_default
			
		if is_instance_valid(zoom_slider): zoom_slider.value = target_zoom
	else:
		target_zoom = zoom_preview_default

func _on_map_state_changed(_room = null) -> void:
	# Czyścimy znacznik, jeśli wpadliśmy do zwykłego Lochu z kafelkami.
	if not _is_camera_mode_active():
		_clear_manual_marker()
		
	_update_camera_limits()
	queue_redraw() 


# =========================================================================
# ORYGINALNY TRYB KAFELKOWY (FALLBACK DLA LOCHÓW / PODZIEMI)
# =========================================================================

func _draw() -> void:
	var current_opacity = opacity_fullscreen if is_map_toggled_large else opacity_preview
	var draw_bg = original_bg_color
	draw_bg.a *= current_opacity
	
	if _is_camera_mode_active():
		draw_rect(Rect2(Vector2.ZERO, size), draw_bg)
		return 
	
	if not level_manager or not level_manager.current_room: return
	
	var current_room = level_manager.current_room
	var center_pos = size / 2.0
	
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	var reference_pos = current_room.map_position
	var current_zoom = 1.0 
	
	if is_map_toggled_large and level_manager.discovered_rooms.size() > 0:
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		
		for r in level_manager.discovered_rooms:
			min_pos.x = min(min_pos.x, r.map_position.x)
			min_pos.y = min(min_pos.y, r.map_position.y)
			max_pos.x = max(max_pos.x, r.map_position.x)
			max_pos.y = max(max_pos.y, r.map_position.y)
			
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

	for room in level_manager.all_rooms:
		if level_manager.discovered_rooms.has(room):
			var diff_x = room.map_position.x - reference_pos.x
			var diff_y = room.map_position.y - reference_pos.y
			var offset = Vector2(diff_x, diff_y) * (actual_cell_size + actual_spacing)
			var box_pos = center_pos + offset - Vector2(actual_cell_size / 2.0, actual_cell_size / 2.0)
			var box_rect = Rect2(box_pos, Vector2(actual_cell_size, actual_cell_size))
			
			var draw_color = discovered_not_visited_color 
			if room == current_room:
				draw_color = current_room_color 
			elif level_manager.visited_rooms.has(room):
				draw_color = visited_room_color 
				
			draw_color.a *= current_opacity
			draw_rect(box_rect, draw_color)
			
			if room == level_manager.starting_room:
				var text = "S"
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var text_pos = box_pos + (Vector2(actual_cell_size, actual_cell_size) / 2.0)
				text_pos.y += text_size.y / 4.0 
				
				var final_txt_color = text_color
				final_txt_color.a *= current_opacity
				draw_string(font, text_pos - Vector2(text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, final_txt_color)
			
			if level_manager.visited_rooms.has(room):
				var target_parent = room
				var loot_icons_to_draw : Array[Texture2D] = []
				for child in target_parent.get_children():
					if child is ItemPickup and child.item != null and child.item.data != null and child.item.data.item_icon != null:
						var item_tex = child.item.data.item_icon
						if not loot_icons_to_draw.has(item_tex):
							loot_icons_to_draw.append(item_tex)
				
				var base_icon_size = Vector2(10, 10) 
				var loot_icon_size = base_icon_size * current_zoom
				var spacing = 2.0 * current_zoom
				var padding = 1.0 * current_zoom
				var current_x_offset = 0.0
				var current_y_offset = 0.0
				
				for tex in loot_icons_to_draw:
					if current_x_offset + loot_icon_size.x + spacing > actual_cell_size:
						current_x_offset = 0.0
						current_y_offset += loot_icon_size.y + padding
					if current_y_offset + loot_icon_size.y + spacing > actual_cell_size:
						break
					var loot_icon_pos = box_pos + Vector2(
						actual_cell_size - loot_icon_size.x - spacing - current_x_offset, 
						actual_cell_size - loot_icon_size.y - spacing - current_y_offset
					)
					draw_texture_rect(tex, Rect2(loot_icon_pos, loot_icon_size), false, Color(1,1,1,current_opacity))
					current_x_offset += loot_icon_size.x + padding
