extends VBoxContainer
## Panel HUD wyświetlający na żywo zagregowane statystyki bojowe, obronne i ruchowe gracza.

const PERCENT_MULTIPLIER: float = 100.0
const STATS_HEADER_NODE_NAME: String = "StatsHeader"

@export var player: PlayerCharacter
var stats_text_label: Label

func _ready() -> void:
	# Tworzymy jeden elastyczny tekst na wszystkie statystyki
	stats_text_label = Label.new()
	add_child(stats_text_label)

	# Ukrywamy stare, sztywne etykiety z edytora, by nie śmieciły na ekranie
	for child in get_children():
		if child != stats_text_label and child.name != STATS_HEADER_NODE_NAME:
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

	# 3. NOWOŚĆ: Nasłuchiwanie nałożenia i wygaśnięcia efektów czasowych / aur środowiskowych!
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

	var text: String = ""

	# --- ZDROWIE I PANCERZ ---
	if hp_stats != null:
		text += "MAX HP: " + str(hp_stats.max_health) + "\n"
		var armor: int = hp_stats.get_total_armor()
		text += "ARMOR: " + str(armor) + "\n\n"

	# --- STATYSTYKI BOJOWE ---
	if atk_stats != null:
		text += "DMG: " + str(atk_stats.get_total_damage()) + "\n"
		text += "CRIT RATE: %.1f%%\n" % (atk_stats.get_total_critical_rate() * PERCENT_MULTIPLIER)
		text += "CRIT DMG: +" + str(atk_stats.get_total_critical_damage()) + "\n"

		var cooldown: float = atk_stats.get_total_actual_cooldown()
		text += "ATK SPEED: %.2fs\n" % cooldown
		text += "RANGE: " + str(atk_stats.get_total_range()) + "\n"

		var stun: float = atk_stats.get_total_stun()
		if stun > 0.0:
			text += "STUN TIME: %.2fs\n" % stun
		text += "\n"

	# --- RUCH ---
	if move_stats != null:
		text += "MOVE SPEED: " + str(move_stats.moveSpeed) + "\n"

	stats_text_label.text = text
