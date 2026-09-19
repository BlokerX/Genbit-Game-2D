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
@export var default_show_hud: bool = true
@export var default_show_hp_bar: bool = true
@export var default_show_minimap: bool = true
@export var default_show_hotbar: bool = true
@export var default_show_quest_log: bool = true

# --- BIEŻĄCE WARTOŚCI ---
var vol_master: float; var vol_music: float; var vol_sfx: float; var vol_ambient: float
var surround_sound: bool; var mute_in_background: bool

var display_mode: int; var vsync_enabled: bool
var brightness: float; var contrast: float; var saturation: float

var ui_scale_global: float; var ui_scale_game: float; var ui_scale_menu: float
var show_hud: bool; var show_hp_bar: bool; var show_minimap: bool; var show_hotbar: bool; var show_quest_log: bool

var config = ConfigFile.new()

# Węzły do globalnego renderowania grafiki
var _bcs_canvas: CanvasLayer
var _bcs_rect: ColorRect

func _ready() -> void:
	# --- SHADER JASNOŚCI, KONTRASTU I NASYCENIA ---
	_bcs_canvas = CanvasLayer.new()
	_bcs_canvas.layer = 128 # Warstwa powyżej interfejsu
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
	
	ui_scale_global = config.get_value("GUI", "ScaleGlobal", default_ui_scale_global)
	ui_scale_game = config.get_value("GUI", "ScaleGame", default_ui_scale_game)
	ui_scale_menu = config.get_value("GUI", "ScaleMenu", default_ui_scale_menu)
	show_hud = config.get_value("GUI", "ShowHUD", default_show_hud)
	show_hp_bar = config.get_value("GUI", "ShowHP", default_show_hp_bar)
	show_minimap = config.get_value("GUI", "ShowMinimap", default_show_minimap)
	show_hotbar = config.get_value("GUI", "ShowHotbar", default_show_hotbar)
	show_quest_log = config.get_value("GUI", "ShowQuestLog", default_show_quest_log)
	
	apply_all_settings()

func save_settings() -> void:
	config.set_value("Audio", "Master", vol_master); config.set_value("Audio", "Music", vol_music)
	config.set_value("Audio", "SFX", vol_sfx); config.set_value("Audio", "Ambient", vol_ambient)
	config.set_value("Audio", "Surround", surround_sound); config.set_value("Audio", "MuteBG", mute_in_background)
	
	config.set_value("Graphics", "DisplayMode", display_mode); config.set_value("Graphics", "VSync", vsync_enabled)
	config.set_value("Graphics", "Brightness", brightness); config.set_value("Graphics", "Contrast", contrast)
	config.set_value("Graphics", "Saturation", saturation)
	
	config.set_value("GUI", "ScaleGlobal", ui_scale_global); config.set_value("GUI", "ScaleGame", ui_scale_game)
	config.set_value("GUI", "ScaleMenu", ui_scale_menu); config.set_value("GUI", "ShowHUD", show_hud)
	config.set_value("GUI", "ShowHP", show_hp_bar); config.set_value("GUI", "ShowMinimap", show_minimap)
	config.set_value("GUI", "ShowHotbar", show_hotbar); config.set_value("GUI", "ShowQuestLog", show_quest_log)
	
	config.save(save_path)
	apply_all_settings()

func apply_all_settings() -> void:
	# Aplikowanie Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(vol_master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(vol_music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(vol_sfx))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(vol_ambient))
	
	# Aplikowanie Grafiki i Cieni
	DisplayServer.window_set_mode(display_mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	
	# Aktualizacja Shadera na żywo
	var mat = _bcs_rect.material as ShaderMaterial
	mat.set_shader_parameter("brightness", brightness)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("saturation", saturation)
	
	# Aplikowanie Skali (Skaluje Główny Viewport)
	get_tree().root.content_scale_factor = ui_scale_global
	
	if EventBus.has_signal("hud_visibility_requested"):
		EventBus.hud_visibility_requested.emit()

# =========================================================================
# LOGIKA RESETOWANIA
# =========================================================================
func reset_all_to_default(auto_save: bool = true) -> void:
	reset_category_audio(false)
	reset_category_graphics(false)
	reset_category_gui(false)
	if auto_save: save_settings()

func reset_category_audio(auto_save: bool = true) -> void:
	vol_master = default_vol_master; vol_music = default_vol_music; vol_sfx = default_vol_sfx
	vol_ambient = default_vol_ambient; surround_sound = default_surround_sound; mute_in_background = default_mute_in_background
	if auto_save: save_settings()

func reset_category_graphics(auto_save: bool = true) -> void:
	display_mode = default_display_mode; vsync_enabled = default_vsync_enabled
	brightness = default_brightness; contrast = default_contrast; saturation = default_saturation
	if auto_save: save_settings()

func reset_category_gui(auto_save: bool = true) -> void:
	ui_scale_global = default_ui_scale_global; ui_scale_game = default_ui_scale_game; ui_scale_menu = default_ui_scale_menu
	show_hud = default_show_hud; show_hp_bar = default_show_hp_bar
	show_minimap = default_show_minimap; show_hotbar = default_show_hotbar; show_quest_log = default_show_quest_log
	if auto_save: save_settings()
