extends Node
# global_settings.gd - Podpięty w Autoload

@export_category("Konfiguracja Zapisu")
## Ścieżka do pliku z ustawieniami. "user://" to folder %APPDATA% gracza.
@export var save_path: String = "user://settings.cfg"

@export_group("Domyślne Wartości - Dźwięk")
@export_range(0.0, 1.0) var default_vol_master: float = 1.0
@export_range(0.0, 1.0) var default_vol_music: float = 1.0
@export_range(0.0, 1.0) var default_vol_sfx: float = 1.0
@export_range(0.0, 1.0) var default_vol_ambient: float = 1.0
@export var default_surround_sound: bool = true
@export var default_mute_in_background: bool = false

@export_group("Domyślne Wartości - Grafika")
@export var default_display_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
@export var default_vsync_enabled: bool = true
@export_range(0.0, 2.0) var default_brightness: float = 1.0
@export_range(0.0, 2.0) var default_contrast: float = 1.0
@export_range(0.0, 2.0) var default_saturation: float = 1.0

@export_group("Domyślne Wartości - Interfejs")
@export_range(0.5, 2.0) var default_ui_scale_global: float = 1.0
@export_range(0.5, 2.0) var default_ui_scale_game: float = 1.0
@export_range(0.5, 2.0) var default_ui_scale_menu: float = 1.0

# Opcje szczegółowe HUD
@export var default_show_main_stats: bool = true
@export var default_show_extra_stats: bool = true
@export var default_show_active_effects: bool = true
@export var default_show_hotbar: bool = true
@export var default_show_item_info: bool = true
@export var default_show_playtime: bool = true
@export var default_show_minimap: bool = true
@export var default_show_quest_log: bool = true

@export_category("World Streaming")
## Zasięg renderowania
var chunk_render_distance: int = 1
var default_chunk_render_distance: int = 3

## Globalny rozmiar chunka w pikselach dla CAŁEJ GRY (zamiast wyliczać go z kafelków)
var chunk_base_size: int = 1024

# --- BIEŻĄCE WARTOŚCI ---
var vol_master: float; var vol_music: float; var vol_sfx: float; var vol_ambient: float
var surround_sound: bool; var mute_in_background: bool

var display_mode: int; var vsync_enabled: bool
var brightness: float; var contrast: float; var saturation: float

var ui_scale_global: float; var ui_scale_game: float; var ui_scale_menu: float

var show_main_stats: bool; var show_extra_stats: bool; var show_active_effects: bool
var show_hotbar: bool; var show_item_info: bool; var show_playtime: bool
var show_minimap: bool; var show_quest_log: bool

var config = ConfigFile.new()

# --- Węzły do globalnego renderowania grafiki ---
var _bcs_canvas: CanvasLayer
var _bcs_rect: ColorRect

func _ready() -> void:
	# --- SHADER JASNOŚCI, KONTRASTU I NASYCENIA ---
	_bcs_canvas = CanvasLayer.new()
	_bcs_canvas.layer = 128 # Warstwa powyżej interfejsu, pod menu pauzy
	_bcs_rect = ColorRect.new()
	_bcs_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bcs_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
	uniform float brightness = 1.0;
	uniform float contrast = 1.0;
	uniform float saturation = 1.0;
	void fragment() {
		vec3 c = texture(screen_texture, SCREEN_UV).rgb;
		c = mix(vec3(0.5), c, contrast);
		c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, saturation);
		c = c * brightness;
		COLOR.rgb = c;
	}
	"""
	mat.shader = shader
	_bcs_rect.material = mat
	_bcs_canvas.add_child(_bcs_rect)
	add_child(_bcs_canvas)

	# Na starcie wczytujemy domyślne, a potem nadpisujemy plikiem gracza (jeśli istnieje)
	reset_all_to_default(false)
	load_settings()

# WYDAJNA PĘTLA O(1) - BEZ WYSZUKIWANIA GRACZA
func _process(_delta: float) -> void:
	if is_instance_valid(_bcs_canvas):
		var in_game = false
		var main_node = get_tree().get_first_node_in_group("Main")
		if main_node and "current_scene" in main_node:
			# Sprawdzamy błyskawicznie, czy wczytana scena to GameScene
			in_game = (main_node.current_scene is GameScene)
			
		# Shader graficzny działa tylko i wyłącznie w GameScene
		_bcs_canvas.visible = in_game

# Nasłuchiwanie wyjścia z gry do Windowsa (Alt-Tab)
func _notification(what: int) -> void:
	if mute_in_background:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
		elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)

func load_settings() -> void:
	if config.load(save_path) != OK:
		save_settings()
		return
	
	vol_master = config.get_value("Audio", "Master", default_vol_master)
	vol_music = config.get_value("Audio", "Music", default_vol_music)
	vol_sfx = config.get_value("Audio", "SFX", default_vol_sfx)
	vol_ambient = config.get_value("Audio", "Ambient", default_vol_ambient)
	surround_sound = config.get_value("Audio", "Surround", default_surround_sound)
	mute_in_background = config.get_value("Audio", "MuteBG", default_mute_in_background)
	
	display_mode = config.get_value("Graphics", "DisplayMode", default_display_mode)
	vsync_enabled = config.get_value("Graphics", "VSync", default_vsync_enabled)
	brightness = config.get_value("Graphics", "Brightness", default_brightness)
	contrast = config.get_value("Graphics", "Contrast", default_contrast)
	saturation = config.get_value("Graphics", "Saturation", default_saturation)
	chunk_render_distance = config.get_value("Graphics", "RenderDistance", default_chunk_render_distance)
	
	ui_scale_global = config.get_value("GUI", "ScaleGlobal", default_ui_scale_global)
	ui_scale_game = config.get_value("GUI", "ScaleGame", default_ui_scale_game)
	ui_scale_menu = config.get_value("GUI", "ScaleMenu", default_ui_scale_menu)
	
	show_main_stats = config.get_value("GUI", "ShowMainStats", default_show_main_stats)
	show_extra_stats = config.get_value("GUI", "ShowExtraStats", default_show_extra_stats)
	show_active_effects = config.get_value("GUI", "ShowActiveEffects", default_show_active_effects)
	show_hotbar = config.get_value("GUI", "ShowHotbar", default_show_hotbar)
	show_item_info = config.get_value("GUI", "ShowItemInfo", default_show_item_info)
	show_playtime = config.get_value("GUI", "ShowPlaytime", default_show_playtime)
	show_minimap = config.get_value("GUI", "ShowMinimap", default_show_minimap)
	show_quest_log = config.get_value("GUI", "ShowQuestLog", default_show_quest_log)
	
	apply_all_settings()

func save_settings() -> void:
	config.set_value("Audio", "Master", vol_master); config.set_value("Audio", "Music", vol_music)
	config.set_value("Audio", "SFX", vol_sfx); config.set_value("Audio", "Ambient", vol_ambient)
	config.set_value("Audio", "Surround", surround_sound); config.set_value("Audio", "MuteBG", mute_in_background)
	
	config.set_value("Graphics", "DisplayMode", display_mode); config.set_value("Graphics", "VSync", vsync_enabled)
	config.set_value("Graphics", "Brightness", brightness); config.set_value("Graphics", "Contrast", contrast)
	config.set_value("Graphics", "Saturation", saturation)
	config.set_value("Graphics", "RenderDistance", chunk_render_distance)
	
	config.set_value("GUI", "ScaleGlobal", ui_scale_global); config.set_value("GUI", "ScaleGame", ui_scale_game)
	config.set_value("GUI", "ScaleMenu", ui_scale_menu)
	
	config.set_value("GUI", "ShowMainStats", show_main_stats); config.set_value("GUI", "ShowExtraStats", show_extra_stats)
	config.set_value("GUI", "ShowActiveEffects", show_active_effects); config.set_value("GUI", "ShowHotbar", show_hotbar)
	config.set_value("GUI", "ShowItemInfo", show_item_info); config.set_value("GUI", "ShowPlaytime", show_playtime)
	config.set_value("GUI", "ShowMinimap", show_minimap); config.set_value("GUI", "ShowQuestLog", show_quest_log)
	
	config.save(save_path)
	apply_all_settings()

func apply_all_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(vol_master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(vol_music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(vol_sfx))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(vol_ambient))
	
	DisplayServer.window_set_mode(display_mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	
	# Aktualizacja Shadera na żywo
	if is_instance_valid(_bcs_rect):
		var mat = _bcs_rect.material as ShaderMaterial
		mat.set_shader_parameter("brightness", brightness)
		mat.set_shader_parameter("contrast", contrast)
		mat.set_shader_parameter("saturation", saturation)
	
	get_tree().root.content_scale_factor = ui_scale_global
	
	# Wymuszamy przegląd drzewa i zastosowanie modyfikacji HUD
	_apply_gui_visibility_to_tree()
	
	if EventBus.has_signal("hud_visibility_requested"):
		EventBus.hud_visibility_requested.emit()

# --- OPTYMALNE APLIKOWANIE WIDOCZNOŚCI I SKALI (Sprytne ukrywanie) ---
func _apply_gui_visibility_to_tree() -> void:
	var ui_canvas = get_tree().root.find_child("UI_Canvas", true, false)
	if not ui_canvas: return
	
	# Skalowanie w Grze
	if "scale" in ui_canvas:
		ui_canvas.scale = Vector2(ui_scale_game, ui_scale_game)
		
	# Odczytywanie i aplikowanie widoczności konkretnych stref w UI_Canvas
	var node_main_stats = ui_canvas.find_child("PlayerUIGroup", true, false)
	if node_main_stats: node_main_stats.visible = show_main_stats
		
	var node_extra_stats = ui_canvas.find_child("StatsPanel", true, false)
	if node_extra_stats: node_extra_stats.visible = show_extra_stats
		
	var node_effects = ui_canvas.find_child("AcriveEffectsPanel", true, false)
	if node_effects: node_effects.visible = show_active_effects
		
	var node_hotbar = ui_canvas.find_child("HotbarPanel", true, false)
	if node_hotbar: node_hotbar.visible = show_hotbar
		
	var node_item_info = ui_canvas.find_child("ItemInfoPanelContainer", true, false)
	if node_item_info: node_item_info.visible = show_item_info
		
	var node_playtime = ui_canvas.find_child("PlaytimeLabel", true, false)
	if node_playtime: node_playtime.visible = show_playtime
		
	# TARCZA NA MINIMAPĘ: Ukrywamy całego kontenera (rodzica), by skrypt minimapy 
	# nie nadpisywał naszej widoczności swoimi lokalnymi funkcjami show()/hide()
	var node_minimap_zone = ui_canvas.find_child("BottomRight_Zone", true, false)
	if node_minimap_zone: node_minimap_zone.visible = show_minimap
		
	var node_quest = ui_canvas.find_child("QuestTrackerUI", true, false)
	if node_quest: node_quest.visible = show_quest_log

	# Skalowanie Menu Inwentarza, Skrzyń, Craftingu
	var menus = ["PauseMenu", "InventoryWindows", "CraftingUI", "QuestLogUI"]
	for m in menus:
		var menu_node = get_tree().root.find_child(m, true, false)
		if menu_node and "scale" in menu_node:
			menu_node.scale = Vector2(ui_scale_menu, ui_scale_menu)

# =========================================================================
# LOGIKA RESETOWANIA
# =========================================================================

func reset_all_to_default(auto_save: bool = true) -> void:
	reset_category_audio(false); reset_category_graphics(false); reset_category_gui(false)
	if auto_save: save_settings()

func reset_category_audio(auto_save: bool = true) -> void:
	vol_master = default_vol_master; vol_music = default_vol_music; vol_sfx = default_vol_sfx
	vol_ambient = default_vol_ambient; surround_sound = default_surround_sound; mute_in_background = default_mute_in_background
	if auto_save: save_settings()

func reset_category_graphics(auto_save: bool = true) -> void:
	display_mode = default_display_mode; vsync_enabled = default_vsync_enabled
	brightness = default_brightness; contrast = default_contrast; saturation = default_saturation
	chunk_render_distance = default_chunk_render_distance
	if auto_save: save_settings()

func reset_category_gui(auto_save: bool = true) -> void:
	ui_scale_global = default_ui_scale_global; ui_scale_game = default_ui_scale_game; ui_scale_menu = default_ui_scale_menu
	show_main_stats = default_show_main_stats; show_extra_stats = default_show_extra_stats
	show_active_effects = default_show_active_effects; show_hotbar = default_show_hotbar; show_item_info = default_show_item_info
	show_playtime = default_show_playtime; show_minimap = default_show_minimap; show_quest_log = default_show_quest_log
	if auto_save: save_settings()
