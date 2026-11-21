extends AbilityComponent
class_name ScreenOverlayAbilityComponent
## Komponent zdolności AI generujący atmosferyczną winietę lub zaćmienie ekranu gracza po trafieniu (SOLID - SRP / OCP).
## Może zostać dodany w pliku .tres do dowolnej zdolności (np. Fala Psychozy, Oślepiająca Wiązka, Błyskowy Wybuch).

const DEFAULT_OVERLAY_LAYER: int = GameLayers.UI_HUD - 5
const ACTIVE_OVERLAY_NODE_NAME: String = "AbilityScreenOverlayVFX"

@export_group("Parametry Nakładki Ekranowej")
## Kolor winiety lub zaciemnienia ekranu po trafieniu (np. mroczny fiolet, oślepiająca biel, zieleń toksyn).
@export var overlay_color: Color = Color(0.05, 0.0, 0.12, 0.92)
## Całkowity czas utrzymywania i wygaszania efektu ekranowego (w sekundach).
@export_range(0.5, 15.0, 0.5) var overlay_duration: float = 5.0
## Promień bardziej przejrzystego środka winiety (0.0 = niemal pełne zasłonięcie, 0.35 = wyraźna ramka).
@export_range(0.0, 0.65, 0.02) var inner_clear_radius: float = 0.18
## Warstwa CanvasLayer dla nakładki (domyślnie tuż pod UI_HUD, aby zachować czytelność pasków i zegara).
@export var canvas_layer: int = DEFAULT_OVERLAY_LAYER
## Jeśli true (domyślnie), efekt ekranowy aktywuje się wyłącznie po trafieniu gracza.
@export var trigger_only_on_player_hit: bool = true

func on_target_hit(_ability: Resource, attacker: CharacterEntity, target: Node2D, _origin_pos: Vector2) -> void:
	if not is_instance_valid(target):
		return
	if trigger_only_on_player_hit and not target.is_in_group("Player"):
		return

	var context_node: Node = target if target.is_inside_tree() else attacker
	if not is_instance_valid(context_node) or not context_node.is_inside_tree():
		return

	var tree: SceneTree = context_node.get_tree()
	if tree == null:
		return
	var host: Node = tree.get_first_node_in_group("Map")
	if not is_instance_valid(host):
		host = tree.current_scene
	if not is_instance_valid(host):
		return

	# Zastępujemy poprzednią nakładkę tej samej klasy, aby szybkie tiki nie spiętrzały dziesiątek warstw CanvasLayer.
	var existing: Node = host.get_node_or_null(ACTIVE_OVERLAY_NODE_NAME)
	if is_instance_valid(existing):
		existing.queue_free()

	var overlay := _ScreenOverlayVFX.new()
	overlay.name = ACTIVE_OVERLAY_NODE_NAME
	overlay.setup(overlay_duration, overlay_color, inner_clear_radius, canvas_layer)
	host.add_child(overlay)

## Shaderowa winieta / mgła ekranowa z płynnym pulsowaniem i wygaszaniem (SRP).
class _ScreenOverlayVFX extends CanvasLayer:
	const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 overlay_color : source_color = vec4(0.05, 0.0, 0.12, 0.92);
uniform float intensity = 0.0;
uniform float inner_clear_radius = 0.18;
uniform float outer_solid_radius = 0.78;
void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5)) * 1.41421356;
	float vignette = smoothstep(inner_clear_radius, outer_solid_radius, dist);
	float alpha = mix(overlay_color.a * 0.48, overlay_color.a, vignette) * intensity;
	COLOR = vec4(overlay_color.rgb, clamp(alpha, 0.0, 1.0));
}
"""
	const FADE_IN_SEC: float = 0.12
	const PULSE_HALF_SEC: float = 0.30
	const MIN_FADE_OUT_SEC: float = 0.15
	const OUTER_SOLID_OFFSET: float = 0.58
	const PULSE_LOW_INTENSITY: float = 0.78
	const PULSE_HIGH_INTENSITY: float = 0.96

	var _duration: float = 5.0
	var _color: Color = Color(0.05, 0.0, 0.12, 0.92)
	var _inner_clear: float = 0.18
	var _target_layer: int = DEFAULT_OVERLAY_LAYER

	func setup(duration: float, color: Color, inner_clear: float, target_layer: int) -> void:
		_duration = duration
		_color = color
		_inner_clear = clampf(inner_clear, 0.0, 0.65)
		_target_layer = target_layer

	func _ready() -> void:
		layer = _target_layer
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var shader := Shader.new()
		shader.code = VIGNETTE_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("overlay_color", _color)
		mat.set_shader_parameter("intensity", 0.0)
		mat.set_shader_parameter("inner_clear_radius", _inner_clear)
		mat.set_shader_parameter("outer_solid_radius", minf(1.0, _inner_clear + OUTER_SOLID_OFFSET))
		rect.material = mat
		add_child(rect)

		var fade_out_sec: float = maxf(MIN_FADE_OUT_SEC, _duration - (FADE_IN_SEC + PULSE_HALF_SEC * 2.0))
		var tween: Tween = create_tween()
		tween.tween_property(mat, "shader_parameter/intensity", 1.0, FADE_IN_SEC)
		tween.tween_property(mat, "shader_parameter/intensity", PULSE_LOW_INTENSITY, PULSE_HALF_SEC).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/intensity", PULSE_HIGH_INTENSITY, PULSE_HALF_SEC).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "shader_parameter/intensity", 0.0, fade_out_sec).set_trans(Tween.TRANS_SINE)
		await tween.finished
		queue_free()
