extends VBoxContainer
## Panel HUD wyświetlający na żywo zagregowane statystyki bojowe, obronne i ruchowe gracza w czytelnym kafelku.

const PERCENT_MULTIPLIER: float = 100.0
const STATS_HEADER_NODE_NAME: String = "StatsHeader"
const STATS_FONT_SIZE: int = 14
const STATS_CARD_PADDING_H: float = 10.0
const STATS_CARD_PADDING_V: float = 8.0

@export var player: PlayerCharacter
var stats_text_label: Label
var _card_panel: PanelContainer

func _ready() -> void:
	var header_lbl: Label = get_node_or_null(STATS_HEADER_NODE_NAME) as Label
	if header_lbl != null:
		UIThemeStyler.apply_readable_label_style(
			header_lbl,
			UIThemeStyler.HEADER_GOLD_COLOR,
			UIThemeStyler.HEADER_OUTLINE_SIZE
		)

	_card_panel = PanelContainer.new()
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.add_theme_stylebox_override(
		"panel",
		UIThemeStyler.create_hud_card_stylebox(STATS_CARD_PADDING_H, STATS_CARD_PADDING_V)
	)
	add_child(_card_panel)

	# Tworzymy jeden elastyczny tekst na wszystkie statystyki wewnątrz kafelka HUD
	stats_text_label = Label.new()
	stats_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_text_label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	UIThemeStyler.apply_readable_label_style(stats_text_label, UIThemeStyler.BODY_LIGHT_TEXT_COLOR)
	_card_panel.add_child(stats_text_label)

	# Ukrywamy stare, sztywne etykiety z edytora, by nie śmieciły na ekranie
	for child in get_children():
		if child != _card_panel and child.name != STATS_HEADER_NODE_NAME:
			if child is CanvasItem:
				(child as CanvasItem).hide()

	call_deferred("_bind_player_signals")

func _bind_player_signals() -> void:
	if not is_instance_valid(player):
		return

	# 1. Nasłuchiwanie zmian w ekwipunku (zmiana broni w ręce, założenie zbroi, pasywki)
	if player.inventory != null:
		if not player.inventory.inventory_updated.is_connected(update_stats_display):
			player.inventory.inventory_updated.connect(update_stats_display)
		if not player.inventory.equipment_updated.is_connected(update_stats_display):
			player.inventory.equipment_updated.connect(update_stats_display)

	# 2. Nasłuchiwanie zmian maksymalnego zdrowia
	if player.get("health_stats_script") != null:
		var hp_stats: MonitoredLifeStatsComponent = player.health_stats_script
		if not hp_stats.max_health_changed.is_connected(_on_max_health_changed):
			hp_stats.max_health_changed.connect(_on_max_health_changed)

	# 3. Nasłuchiwanie nałożenia i wygaśnięcia efektów czasowych / aur środowiskowych!
	if player.get("effects_collector") != null and is_instance_valid(player.effects_collector):
		if not player.effects_collector.child_entered_tree.is_connected(_on_active_effects_changed):
			player.effects_collector.child_entered_tree.connect(_on_active_effects_changed)
		if not player.effects_collector.child_exiting_tree.is_connected(_on_active_effects_changed):
			player.effects_collector.child_exiting_tree.connect(_on_active_effects_changed)

	update_stats_display()

func _on_max_health_changed(_new_max_hp: int) -> void:
	update_stats_display()

## Odświeża wyświetlacz na koniec klatki (po wykonaniu on_effect_start / on_effect_end w ActiveEffect).
func _on_active_effects_changed(_node: Node) -> void:
	call_deferred("update_stats_display")

func update_stats_display() -> void:
	if not is_instance_valid(player) or stats_text_label == null:
		return

	var atk_stats: InteractionAndAttackStatsComponent = player.get("interaction_and_attack_stats_script") as InteractionAndAttackStatsComponent
	var hp_stats: LifeStatsComponent = player.get("health_stats_script") as LifeStatsComponent
	var move_stats: MovementComponent = player.get("movement_universal_script") as MovementComponent

	var lines: PackedStringArray = PackedStringArray()

	# --- ZDROWIE I PANCERZ ---
	if hp_stats != null:
		lines.append("MAX HP: " + str(hp_stats.max_health))
		lines.append("ARMOR: " + str(hp_stats.get_total_armor()))

	# --- STATYSTYKI BOJOWE ---
	if atk_stats != null:
		lines.append("DMG: " + str(atk_stats.get_total_damage()))
		lines.append("CRIT RATE: %.1f%%" % (atk_stats.get_total_critical_rate() * PERCENT_MULTIPLIER))
		lines.append("CRIT DMG: +" + str(atk_stats.get_total_critical_damage()))
		lines.append("ATK SPEED: %.2fs" % atk_stats.get_total_actual_cooldown())
		lines.append("RANGE: " + str(atk_stats.get_total_range()))
		var stun: float = atk_stats.get_total_stun()
		if stun > 0.0:
			lines.append("STUN TIME: %.2fs" % stun)

	# --- RUCH ---
	if move_stats != null:
		lines.append("MOVE SPEED: " + str(move_stats.moveSpeed))

	stats_text_label.text = "\n".join(lines)
