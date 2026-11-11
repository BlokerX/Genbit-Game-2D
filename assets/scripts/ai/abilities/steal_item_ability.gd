extends AIAbility
class_name StealItemAbility
## Zdolność specjalna AI: Doskok z próbą wytrącenia/kradzieży trzymanego przedmiotu opartą na prawdopodobieństwie.

const HALF_CAST_TIME_FACTOR: float = 0.5
const DEBUG_VISUAL_Z_INDEX: int = 100
const FULL_RESISTANCE_THRESHOLD: float = 1.0

@export_category("Zdolność: Kradzież Ekwipunku")
@export_group("Obrażenia i Szansa Kradzieży")
@export var damage: int = 12
## Bazowa szansa powodzenia kradzieży/wytrącenia przedmiotu po trafieniu (0.0 = 0%, 1.0 = 100%).
@export_range(0.0, 1.0, 0.01) var steal_success_chance: float = 0.35
## Czy odporność na kontrolę tłumu celu (cc_resistance) zmniejsza szansę na kradzież?
@export var affected_by_target_cc_resistance: bool = true
## Jeśli true, wytrąca cały stos z dłoni. Jeśli false, wytrąca tylko 1 sztukę przedmiotu.
@export var steal_entire_stack: bool = true

@export_group("Parametry Doskoku")
## Czas trwania pełnej animacji (doskok i powrót).
@export_range(0.1, 2.0, 0.1) var cast_time: float = 0.3
## Maksymalny dystans, na jaki mutant może rzucić się do przodu w trakcie ataku.
@export_range(10.0, 100.0, 5.0) var dash_distance: float = 120.0
## Margines tolerancji dystansu po zakończeniu doskoku (od krawędzi do krawędzi!). 
@export_range(0.0, 50.0, 5.0) var hit_distance_leeway: float = 60.0

@export_group("Debug")
## Jeśli włączone, w konsoli pojawią się logi, a na ekranie narysuje się graficzny obszar ataku.
@export var debug_mode: bool = true

func _init() -> void:
	ability_name = "Kradzież Ekwipunku"
	cooldown = 12.0
	min_range = 0.0
	max_range = 110.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		if debug_mode:
			print("[StealItem] Przerwano: Atakujący lub Cel przestał istnieć na starcie.")
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	if debug_mode: 
		print("[StealItem] %s rozpoczyna atak na %s!" % [attacker.name, target.name])

	# --- ZWRÓCENIE SIĘ W STRONĘ CELU PRZED ATAKIEM ---
	var aim_direction: Vector2 = attacker.global_position.direction_to(target.global_position)
	orient_towards(attacker, aim_direction)

	# --- OBLICZANIE IDEALNEGO DOSKOKU (Edge-to-Edge) ---
	var original_pos: Vector2 = attacker.global_position
	var attacker_rad: float = attacker.combat_radius
	var target_rad: float = target.combat_radius
	var edge_distance: float = get_edge_distance(attacker, target)

	var actual_dash_distance: float = minf(dash_distance, edge_distance)
	var move_vec: Vector2 = aim_direction * actual_dash_distance

	var col: KinematicCollision2D = attacker.move_and_collide(move_vec, true)
	var forward_pos: Vector2 = original_pos + move_vec
	if col != null:
		forward_pos = original_pos + col.get_travel()
		if debug_mode:
			print("[StealItem] Ściana na drodze! Skracam doskok z %s do %s pikseli." % [actual_dash_distance, col.get_travel().length()])

	var half_cast: float = cast_time * HALF_CAST_TIME_FACTOR
	var dash_in_tween: Tween = create_kinematic_dash_tween(attacker, forward_pos, half_cast, Tween.TRANS_SINE, Tween.EASE_OUT)

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	await dash_in_tween.finished
	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	# --- SPRAWDZENIE TRAFIENIA I LOSOWANIE SZANSY KRADZIEŻY W SZCZYCIE DOSKOKU ---
	if is_instance_valid(attacker) and is_instance_valid(target) and not target.is_dead and not target.is_respawning:
		var post_dash_edge_dist: float = get_edge_distance(attacker, target)
		var hit_threshold: float = max_range + hit_distance_leeway
		var is_hit: bool = post_dash_edge_dist <= hit_threshold

		if debug_mode: 
			print("[StealItem] Krawędzie oddalone o %s px (Tolerancja wynosi %s px)." % [round(post_dash_edge_dist), hit_threshold])
			var debug_vis: StealDebugVisual = StealDebugVisual.new()
			debug_vis.radius = hit_threshold + attacker_rad + target_rad 
			debug_vis.hit_success = is_hit
			debug_vis.target_pos = target.global_position
			debug_vis.z_index = DEBUG_VISUAL_Z_INDEX
			spawn_ability_node(attacker, debug_vis, attacker.global_position)

		if is_hit:
			if debug_mode:
				print("[StealItem] Cel w zasięgu! Atak fizyczny ląduje.")

			var dmg: DamageEffect = DamageEffect.new(damage)
			dmg.source_entity = attacker
			dmg.source_position = attacker.global_position
			if target.has_method("receive_effect"):
				target.receive_effect(dmg)

			# Jeśli cel przeżył uderzenie, wykonujemy rzut na szansę wytrącenia przedmiotu!
			if is_instance_valid(target) and not target.is_dead and not target.is_respawning:
				_try_steal_held_item(attacker, target)

	# Powrót na pozycję startową
	var dash_back_tween: Tween = create_kinematic_dash_tween(attacker, original_pos, half_cast, Tween.TRANS_SINE, Tween.EASE_IN)
	if is_instance_valid(attacker) and attacker.is_inside_tree():
		await dash_back_tween.finished

	if is_instance_valid(attacker) and combat_ctrl != null:
		combat_ctrl.is_casting_ability = false

## Wykonuje test prawdopodobieństwa i (w razie sukcesu) wytrąca przedmiot z dłoni celu.
func _try_steal_held_item(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not target.has_method("get_inventory"):
		return
	var inv = target.get_inventory()
	if not (inv is Inventory):
		return

	var slot: SlotData = (inv as Inventory).get_current_slot()
	if slot == null or slot.is_empty() or slot.item == null:
		return

	var effective_chance: float = _calculate_effective_steal_chance(attacker, target, slot.item)
	if effective_chance <= 0.0:
		if debug_mode:
			print("[StealItem] Cel lub przedmiot jest całkowicie odporny na kradzież!")
		return

	var roll: float = randf()
	if roll <= effective_chance:
		var stolen_item_name: String = slot.item.data.item_name if slot.item.data != null else "Nieznany Przedmiot"
		print("%s wytrąca przedmiot graczowi! (%s | Szansa: %d%%)" % [attacker.name, stolen_item_name, int(effective_chance * 100.0)])
		(inv as Inventory).drop_current_item(steal_entire_stack)
	elif debug_mode:
		print("[StealItem] Próba kradzieży nieudana (Wylosowano: %.2f > Wymagane: %.2f)." % [roll, effective_chance])

## Oblicza ostateczną szansę powodzenia kradzieży z uwzględnieniem odporności celu oraz właściwości przedmiotu.
func _calculate_effective_steal_chance(_attacker: CharacterEntity, target: CharacterEntity, item_instance: ItemInstance) -> float:
	if steal_success_chance <= 0.0 or item_instance == null:
		return 0.0

	# 1. Sprawdzenie, czy sam przedmiot lub stan postaci blokuje kradzież (wsparcie dla unikalnych itemów i buffów)
	if item_instance.state.get("cannot_be_stolen", false) == true:
		return 0.0
	if target.has_meta("immune_to_steal") and bool(target.get_meta("immune_to_steal")) == true:
		return 0.0
	if target.has_method("is_action_blocked") and bool(target.call("is_action_blocked", &"steal")):
		return 0.0

	var chance: float = steal_success_chance

	# 2. Uwzględnienie odporności na kontrolę tłumu (cc_resistance) lub dedykowanej odporności na kradzież
	var resistance: float = 0.0
	if affected_by_target_cc_resistance and target.get("health_stats_script") != null:
		resistance = maxf(resistance, float(target.health_stats_script.cc_resistance))
	if target.has_meta("steal_resistance"):
		resistance = clampf(resistance + float(target.get_meta("steal_resistance")), 0.0, FULL_RESISTANCE_THRESHOLD)

	if resistance >= FULL_RESISTANCE_THRESHOLD:
		return 0.0

	return clampf(chance * (1.0 - resistance), 0.0, 1.0)

# ==============================================================================
# KLASA WEWNĘTRZNA: Graficzny Debugger
# ==============================================================================
class StealDebugVisual extends Node2D:
	var radius: float = 0.0
	var duration: float = 1.5 
	var elapsed: float = 0.0
	var hit_success: bool = false
	var target_pos: Vector2 = Vector2.ZERO

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var alpha: float = clampf(1.0 - (elapsed / maxf(0.01, duration)), 0.0, 1.0)
		var fill_color: Color = Color(0.0, 1.0, 0.0, alpha * 0.2) if hit_success else Color(1.0, 0.0, 0.0, alpha * 0.2)
		var outline_color: Color = Color(0.0, 1.0, 0.0, alpha * 0.8) if hit_success else Color(1.0, 0.0, 0.0, alpha * 0.8)

		draw_circle(Vector2.ZERO, radius, fill_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline_color, 2.0)

		if target_pos != Vector2.ZERO:
			var local_target: Vector2 = to_local(target_pos)
			draw_line(Vector2.ZERO, local_target, outline_color, 2.0)
			draw_circle(local_target, 4.0, outline_color)
