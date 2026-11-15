extends VBoxContainer
## Panel HUD wyświetlający aktywne efekty czasowe (buffy i debuffy) w czytelnych kafelkach wraz z ikonami i licznikami czasu.

const EFFECT_ICON_SIZE_PX := Vector2(28.0, 28.0)
const DECIMAL_DISPLAY_THRESHOLD_SEC: float = 10.0
const INFINITE_DURATION_SYMBOL: String = "∞"
const BADGE_PADDING_H: float = 8.0
const BADGE_PADDING_V: float = 4.0
const BADGE_BORDER_ALPHA: float = 0.55
const BADGE_HBOX_SEPARATION_PX: int = 6

@export var player: PlayerCharacter
@onready var effects_label: Label = $EffectsLabel

var displayed_effects: Dictionary = {}

func _ready() -> void:
	if effects_label:
		UIThemeStyler.apply_readable_label_style(
			effects_label,
			UIThemeStyler.HEADER_GOLD_COLOR,
			UIThemeStyler.HEADER_OUTLINE_SIZE
		)
		effects_label.visible = false
	set_process(false)
	call_deferred("_connect_to_collector")

func _connect_to_collector() -> void:
	if player and "effects_collector" in player and player.effects_collector:
		player.effects_collector.child_entered_tree.connect(_on_effect_added)
		player.effects_collector.child_exiting_tree.connect(_on_effect_removed)

func _process(_delta: float) -> void:
	var stale_keys: Array[String] = []
	for eff_name in displayed_effects.keys():
		var data: Dictionary = displayed_effects[eff_name]
		var effect_node: Node = data.get("effect_node") as Node
		var label: Label = data.get("time_label") as Label

		if is_instance_valid(effect_node) and not effect_node.is_queued_for_deletion() and effect_node.is_inside_tree():
			_format_time_label(label, float(effect_node.get("duration")), bool(effect_node.get("is_infinite")))
		else:
			stale_keys.append(eff_name)

	# Automatyczne sprzątanie osieroconych wpisów
	for stale_key in stale_keys:
		_remove_displayed_effect_by_name(stale_key)

func _on_effect_added(node: Node) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	# NAPRAWA WYŚCIGU WĄTKÓW: Sprawdzamy, czy po odczekaniu 1 klatki węzeł nadal żyje w drzewie
	# i nie został w międzyczasie usunięty (np. przez purge_absolutely_everything przy respawnie)!
	if (
		not is_inside_tree()
		or not is_instance_valid(node)
		or node.is_queued_for_deletion()
		or not node.is_inside_tree()
		or not node.get("effect_resource")
	):
		return

	var res: Resource = node.get("effect_resource")

	# --- TARCZA: Ukrywanie efektów pasywnych i środowiskowych w UI ---
	if res.has_meta("passive_source"):
		return
	if res.has_meta("is_environment_aura") and res.get_meta("is_environment_aura") == true:
		return
	if node.has_meta("is_environment_aura") and node.get_meta("is_environment_aura") == true:
		return

	var eff_name: String = str(res.get("effect_name"))
	if not displayed_effects.has(eff_name):
		_create_effect_icon(node, res)
		set_process(true)
		if effects_label:
			effects_label.visible = true
	else:
		# Jeśli efekt o tej nazwie został zastąpiony nowym węzłem, aktualizujemy wskaźnik
		displayed_effects[eff_name]["effect_node"] = node

func _on_effect_removed(node: Node) -> void:
	if node != null and node.get("effect_resource") != null:
		var eff_name: String = str(node.get("effect_resource").get("effect_name"))
		# Usuwamy wpis tylko, jeśli należy do tego konkretnego węzła (lub węzeł w słowniku już nie żyje)
		if displayed_effects.has(eff_name):
			var tracked_node: Node = displayed_effects[eff_name].get("effect_node") as Node
			if tracked_node == node or not is_instance_valid(tracked_node):
				_remove_displayed_effect_by_name(eff_name)

func _remove_displayed_effect_by_name(eff_name: String) -> void:
	if not displayed_effects.has(eff_name):
		return
	var container: Node = displayed_effects[eff_name].get("container") as Node
	if is_instance_valid(container):
		container.queue_free()
	displayed_effects.erase(eff_name)

	if displayed_effects.is_empty():
		set_process(false)
		if effects_label:
			effects_label.visible = false

func _create_effect_icon(effect_node: Node, effect_resource: Resource) -> void:
	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style: StyleBoxFlat = UIThemeStyler.create_hud_card_stylebox(BADGE_PADDING_H, BADGE_PADDING_V)

	var effect_color: Color = Color.WHITE
	if effect_resource.get("effect_color") != null:
		effect_color = effect_resource.get("effect_color")

	badge_style.border_color = Color(effect_color.r, effect_color.g, effect_color.b, BADGE_BORDER_ALPHA)
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	var container: HBoxContainer = HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", BADGE_HBOX_SEPARATION_PX)
	badge_panel.add_child(container)

	if effect_resource.get("icon") != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = effect_resource.get("icon")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = EFFECT_ICON_SIZE_PX
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		container.add_child(icon)

	var name_label: Label = Label.new()
	name_label.text = str(effect_resource.get("effect_name")) + ": "
	UIThemeStyler.apply_readable_label_style(name_label, effect_color)
	container.add_child(name_label)

	var time_label: Label = Label.new()
	UIThemeStyler.apply_readable_label_style(time_label, Color.WHITE)
	container.add_child(time_label)

	add_child(badge_panel)

	var eff_name: String = str(effect_resource.get("effect_name"))
	displayed_effects[eff_name] = {
		"container": badge_panel,
		"time_label": time_label,
		"effect_node": effect_node
	}

func _format_time_label(label: Label, time_left: float, is_infinite: bool) -> void:
	if label == null:
		return
	if is_infinite:
		label.text = INFINITE_DURATION_SYMBOL
		return
	if time_left > DECIMAL_DISPLAY_THRESHOLD_SEC:
		label.text = str(int(time_left)) + "s"
	else:
		label.text = "%.1f" % maxf(0.0, time_left) + "s"
