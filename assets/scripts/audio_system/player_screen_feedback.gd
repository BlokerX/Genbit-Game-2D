class_name PlayerScreenFeedback
extends CanvasLayer
## Warstwa interfejsu (CanvasLayer) rysująca dynamiczne obwódki ekranu gracza
## (czerwona ramka przy niskim HP, niebieska przy zamrożeniu oraz zielona przy leczeniu).

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

#region Stałe Kolorów i Parametrów Pulsowania (Brak magicznych liczb)
const FROZEN_BORDER_COLOR := Color(0.25, 0.75, 1.0, 1.0)
const HEALING_BORDER_COLOR := Color(0.25, 1.0, 0.45, 1.0)

const FROZEN_BASE_STRENGTH: float = 0.58
const FROZEN_PULSE_AMPLITUDE: float = 0.14
const FROZEN_PULSE_SPEED_RAD: float = 2.0

const LOW_HEALTH_BASE_RATIO: float = 0.78
const LOW_HEALTH_PULSE_RATIO: float = 0.22
const LOW_HEALTH_PULSE_SPEED_RAD: float = 3.0

const MIN_FLASH_DURATION_SEC: float = 0.01
#endregion

@export_group("Obwódka ekranu")
## Intensywność obwódki utrzymywanej przy niskim zdrowiu.
@export_range(0.0, 1.0, 0.01) var low_health_strength: float = 0.48
## Szerokość kolorowej ramki jako część krótszego wymiaru ekranu.
@export_range(0.01, 0.4, 0.01) var border_width: float = 0.12
## Kolor sygnalizujący krytycznie niski poziom zdrowia.
@export var low_health_color: Color = Color(1.0, 0.04, 0.04, 1.0)

@export_group("Obwódka leczenia")
## Czas pełnego zielonego rozjaśnienia po natychmiastowym uleczeniu (np. apteczka / mikstura).
@export_range(0.1, 1.0, 0.05) var healing_flash_duration: float = 0.35
## Maksymalna intensywność pełnego zielonego rozjaśnienia ekranu.
@export_range(0.05, 1.0, 0.02) var healing_flash_strength: float = 0.72
## Czas delikatnego zielonego impulsu ekranu przy tiku regeneracji w czasie.
@export_range(0.1, 1.0, 0.05) var healing_subtle_flash_duration: float = 0.30
## Maksymalna intensywność delikatnego zielonego impulsu ekranu przy tiku regeneracji.
@export_range(0.05, 1.0, 0.02) var healing_subtle_flash_strength: float = 0.28

var _overlay_material: ShaderMaterial
var _low_health_active: bool = false
var _frozen_active: bool = false
var _status_remaining: float = 0.0
var _status_duration: float = 0.0
var _status_peak_strength: float = 0.0
var _pulse_phase: float = 0.0

func _ready() -> void:
	# Warstwa tuż pod czarnym ekranem przejścia (UI_TRANSITION), aby ściemnianie przykrywało obwódkę.
	layer = GameLayers.UI_TRANSITION - 1
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

	var strength: float = 0.0
	var color: Color = low_health_color

	if _frozen_active:
		color = FROZEN_BORDER_COLOR
		strength = FROZEN_BASE_STRENGTH + FROZEN_PULSE_AMPLITUDE * sin(_pulse_phase * FROZEN_PULSE_SPEED_RAD)
	elif _status_remaining > 0.0:
		color = HEALING_BORDER_COLOR
		var progress: float = 1.0 - (_status_remaining / maxf(MIN_FLASH_DURATION_SEC, _status_duration))
		strength = _status_peak_strength * sin(progress * PI)
	elif _low_health_active:
		strength = low_health_strength * (
			LOW_HEALTH_BASE_RATIO + LOW_HEALTH_PULSE_RATIO * sin(_pulse_phase * LOW_HEALTH_PULSE_SPEED_RAD)
		)

	_overlay_material.set_shader_parameter("border_color", color)
	_overlay_material.set_shader_parameter("strength", strength)

## Utrzymuje czerwoną obwódkę, dopóki zdrowie pozostaje poniżej progu.
func set_low_health(is_active: bool) -> void:
	_low_health_active = is_active

## Utrzymuje niebieską obwódkę przez cały czas zamrożenia.
func set_frozen(is_active: bool) -> void:
	_frozen_active = is_active

## Pokazuje zielone rozjaśnienie krawędzi ekranu po faktycznym przywróceniu zdrowia.
## Parametr is_subtle = true uruchamia łagodny impuls (idealny dla tików regeneracji).
func show_healing_feedback(is_subtle: bool = false) -> void:
	var target_strength: float = healing_subtle_flash_strength if is_subtle else healing_flash_strength
	var target_duration: float = healing_subtle_flash_duration if is_subtle else healing_flash_duration

	# Słabszy impuls (np. tick regeneracji) nie przerywa silniejszego, aktualnie trwającego błysku apteczki.
	if _status_remaining > 0.0 and target_strength < _status_peak_strength:
		return

	_status_peak_strength = target_strength
	_status_duration = maxf(MIN_FLASH_DURATION_SEC, target_duration)
	_status_remaining = _status_duration
