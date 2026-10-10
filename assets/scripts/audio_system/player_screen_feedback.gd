class_name PlayerScreenFeedback
extends CanvasLayer

const BORDER_SHADER := """
shader_type canvas_item;
uniform vec4 border_color : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform float strength = 0.0;
uniform float border_width = 0.12;
void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border_alpha = 1.0 - smoothstep(0.0, border_width, edge_distance);
	COLOR = vec4(border_color.rgb, border_alpha * border_color.a * strength);
}
"""
const FROZEN_BORDER_COLOR := Color(0.25, 0.75, 1.0, 1.0)
const HEALING_BORDER_COLOR := Color(0.25, 1.0, 0.45, 1.0)

@export_group("Obwódka ekranu")
## Intensywność obwódki utrzymywanej przy niskim zdrowiu.
@export_range(0.0, 1.0, 0.01) var low_health_strength: float = 0.48
## Szerokość kolorowej ramki jako część krótszego wymiaru ekranu.
@export_range(0.01, 0.4, 0.01) var border_width: float = 0.12
## Kolor sygnalizujący krytycznie niski poziom zdrowia.
@export var low_health_color: Color = Color(1.0, 0.04, 0.04, 1.0)
## Czas krótkiego zielonego rozjaśnienia po faktycznym przywróceniu zdrowia.
@export_range(0.1, 1.0, 0.05) var healing_flash_duration: float = 0.35

var _overlay_material: ShaderMaterial
var _low_health_active: bool = false
var _frozen_active: bool = false
var _status_remaining: float = 0.0
var _status_duration: float = 0.0
var _pulse_phase: float = 0.0

func _ready() -> void:
	layer = 110
	var overlay := ColorRect.new()
	overlay.name = "ScreenBorder"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BORDER_SHADER
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("border_color", low_health_color)
	_overlay_material.set_shader_parameter("border_width", border_width)
	_overlay_material.set_shader_parameter("strength", 0.0)
	overlay.material = _overlay_material
	add_child(overlay)

func _process(delta: float) -> void:
	_pulse_phase += delta
	_status_remaining = maxf(0.0, _status_remaining - delta)
	var strength := 0.0
	var color := low_health_color
	if _frozen_active:
		color = FROZEN_BORDER_COLOR
		strength = 0.58 + 0.14 * sin(_pulse_phase * 2.0)
	elif _status_remaining > 0.0:
		color = HEALING_BORDER_COLOR
		var progress := 1.0 - (_status_remaining / _status_duration)
		strength = 0.72 * sin(progress * PI)
	elif _low_health_active:
		strength = low_health_strength * (0.78 + 0.22 * sin(_pulse_phase * 3.0))
	_overlay_material.set_shader_parameter("border_color", color)
	_overlay_material.set_shader_parameter("strength", strength)

## Utrzymuje czerwoną obwódkę, dopóki zdrowie pozostaje poniżej progu.
func set_low_health(is_active: bool) -> void:
	_low_health_active = is_active

## Utrzymuje niebieską obwódkę przez cały czas zamrożenia.
func set_frozen(is_active: bool) -> void:
	_frozen_active = is_active

## Pokazuje krótkie, płynne rozjaśnienie po przywróceniu zdrowia.
func show_healing_feedback() -> void:
	_status_duration = healing_flash_duration
	_status_remaining = healing_flash_duration
