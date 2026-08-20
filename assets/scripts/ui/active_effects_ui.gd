extends VBoxContainer

@export var player: PlayerCharacter
@onready var effects_label: Label = $EffectsLabel
var displayed_effects: Dictionary = {}

func _ready() -> void:
	if effects_label:
		effects_label.visible = false
	set_process(false)
	call_deferred("_connect_to_collector")

func _connect_to_collector() -> void:
	if player and "effects_collector" in player and player.effects_collector:
		# Godot automatycznie emituje te sygnały, gdy dodasz lub usuniesz dziecko!
		player.effects_collector.child_entered_tree.connect(_on_effect_added)
		player.effects_collector.child_exiting_tree.connect(_on_effect_removed)

func _process(_delta: float) -> void:
	# _process kręci się TYLKO gdy są jakieś efekty. Aktualizujemy same napisy czasu.
	for data in displayed_effects.values():
		var effect_node = data["effect_node"]
		var label = data["time_label"]
		if is_instance_valid(effect_node):
			_format_time_label(label, effect_node.duration, effect_node.is_infinite)

func _on_effect_added(node: Node) -> void:
	# Czekamy ułamek sekundy na inicjalizację zmiennych w nowym węźle
	await get_tree().process_frame 
	if not is_instance_valid(node) or not node.get("effect_resource"):
		return
		
	var res = node.effect_resource
	if not displayed_effects.has(res.effect_name):
		_create_effect_icon(node, res)
		
	set_process(true)
	if effects_label: effects_label.visible = true

func _on_effect_removed(node: Node) -> void:
	if node.get("effect_resource") != null:
		var eff_name = node.effect_resource.effect_name
		if displayed_effects.has(eff_name):
			displayed_effects[eff_name]["container"].queue_free()
			displayed_effects.erase(eff_name)
			
	if displayed_effects.is_empty():
		set_process(false)
		if effects_label: effects_label.visible = false

func _create_effect_icon(effect_node: Node, effect_resource: Resource) -> void:
	var container: Container
	var has_icon = effect_resource.get("icon") != null
	var effect_color: Color = Color.WHITE
	
	if effect_resource.get("effect_color") != null:
		effect_color = effect_resource.effect_color

	if has_icon:
		container = VBoxContainer.new()
		var icon = TextureRect.new()
		icon.texture = effect_resource.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(32, 32)
		container.add_child(icon)
	else:
		container = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = effect_resource.effect_name + ": "
		name_label.add_theme_color_override("font_color", effect_color)
		container.add_child(name_label)

	var time_label = Label.new()
	time_label.add_theme_color_override("font_color", effect_color)
	if has_icon:
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	container.add_child(time_label)
	add_child(container)
	
	displayed_effects[effect_resource.effect_name] = {
		"container": container,
		"time_label": time_label,
		"effect_node": effect_node
	}

func _format_time_label(label: Label, time_left: float, is_infinite: bool) -> void:
	if is_infinite:
		label.text = "∞"
		return
	if time_left > 10.0:
		label.text = str(int(time_left)) + "s"
	else:
		label.text = "%.1f" % time_left + "s"
