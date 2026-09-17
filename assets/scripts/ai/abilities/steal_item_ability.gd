extends AIAbility
class_name StealItemAbility

@export_category("Zdolność: Kradzież Ekwipunku")

@export_group("Obrażenia i Kradzież")
@export var damage: int = 12

@export_group("Parametry Doskoku")
## Czas trwania pełnej animacji (doskok i powrót).
@export_range(0.1, 2.0, 0.1) var cast_time: float = 0.3
## Maksymalny dystans, na jaki mutant może rzucić się do przodu w trakcie ataku.
@export_range(10.0, 100.0, 5.0) var dash_distance: float = 120.0
## Margines tolerancji dystansu po zakończeniu doskoku (od krawędzi do krawędzi!). 
## Określa, o ile gracz może uciec, by atak wciąż był uznany za trafiony.
@export_range(0.0, 50.0, 5.0) var hit_distance_leeway: float = 60.0

@export_group("Debug")
## Jeśli włączone, w konsoli pojawią się logi, a na ekranie narysuje się graficzny obszar ataku.
@export var debug_mode: bool = true

func _init() -> void:
	ability_name = "Kradzież Ekwipunku"
	cooldown = 12.0
	min_range = 0.0
	max_range = 110

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	# Podstawowe zabezpieczenie przed startem
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		if debug_mode: print("[StealItem] Przerwano: Atakujący lub Cel przestał istnieć na starcie.")
		return

	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate: bool = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl: 
		combat_ctrl.is_casting_ability = true

	if debug_mode: 
		print("[StealItem] %s rozpoczyna atak na %s!" % [attacker.name, target.name])

	# --- ZWRÓCENIE SIĘ W STRONĘ CELU PRZED ATAKIEM ---
	var aim_direction = attacker.global_position.direction_to(target.global_position)
	if can_rotate:
		attacker.rotation = aim_direction.angle()
	elif attacker.has_method("_update_sprite_direction"):
		attacker._update_sprite_direction(aim_direction)

	# --- OBLICZANIE IDEALNEGO DOSKOKU (Edge-to-Edge na bazie CharacterEntity) ---
	var original_pos = attacker.global_position
	var center_dist = original_pos.distance_to(target.global_position)
	
	# Bezpiecznie pobieramy grubości postaci (jeśli nie mają zmiennej combat_radius, zakładamy 40.0)
	var attacker_rad = attacker.combat_radius if "combat_radius" in attacker else 40.0
	var target_rad = target.combat_radius if "combat_radius" in target else 40.0
	
	# Dystans od krawędzi mutanta do krawędzi gracza
	var edge_distance = max(0.0, center_dist - (attacker_rad + target_rad))
	
	# Mutant skoczy o ustalone dash_distance, CHYBA ŻE gracz jest bliżej - wtedy skoczy dokładnie do styku!
	var actual_dash_distance = min(dash_distance, edge_distance)
	var move_vec = aim_direction * actual_dash_distance
	
	# --- BEZPIECZNY DOSKOK (Fizyka uderzania w ściany) ---
	var col = attacker.move_and_collide(move_vec, true)
	var forward_pos = original_pos + move_vec
	
	if col:
		# Jeśli po drodze jest ściana, dodajemy wektor przebytej drogi
		forward_pos = original_pos + col.get_travel()
		if debug_mode: print("[StealItem] Ściana na drodze! Skracam doskok z %s do %s pikseli." % [actual_dash_distance, col.get_travel().length()])

	# Błyskawiczny cios w kierunku gracza
	var tween = attacker.create_tracked_tween()
	tween.tween_property(attacker, "global_position", forward_pos, cast_time / 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(attacker, "global_position", original_pos, cast_time / 2.0).set_trans(Tween.TRANS_SINE)

	# Czekamy na koniec animacji uderzenia w cel
	await attacker.get_tree().create_timer(cast_time).timeout

	# --- SPRAWDZENIE TRAFIENIA I KRADZIEŻ ---
	if is_instance_valid(attacker) and is_instance_valid(target):
		var post_dash_center_dist = attacker.global_position.distance_to(target.global_position)
		var post_dash_edge_dist = max(0.0, post_dash_center_dist - (attacker_rad + target_rad))
		
		# Hitbox krawędziowy (0.0 styk + margines wybaczenia błędu)
		var hit_threshold = max_range + hit_distance_leeway
		var is_hit = post_dash_edge_dist <= hit_threshold
		
		# =========================================================
		# RYSOWANIE GRAFICZNEGO DEBUGGERA
		# =========================================================
		if debug_mode: 
			print("[StealItem] Krawędzie oddalone o %s px (Tolerancja wynosi %s px)." % [round(post_dash_edge_dist), hit_threshold])
			var debug_vis = StealDebugVisual.new()
			# Promień koła uwzględnia promienie obu postaci dla prawidłowej skali rysowania okręgu
			debug_vis.radius = hit_threshold + attacker_rad + target_rad 
			debug_vis.hit_success = is_hit
			debug_vis.target_pos = target.global_position
			debug_vis.z_index = 100 
			attacker.get_tree().current_scene.add_child(debug_vis)
			debug_vis.global_position = attacker.global_position
		
		if is_hit:
			if debug_mode: print("[StealItem] Cel w zasięgu! Atak ląduje.")
			
			var dmg = DamageEffect.new(damage)
			dmg.source_entity = attacker
			dmg.source_position = attacker.global_position
			
			if target.has_method("receive_effect"):
				target.receive_effect(dmg)
				
			# KRADZIEŻ: Wytrącenie przedmiotu
			if target.has_method("get_inventory"):
				var inv = target.get_inventory()
				
				# Upewniamy się, że to faktycznie ekwipunek Gracza (bo tylko on ma drop_current_item)
				if inv is Inventory:
					var slot = inv.get_current_slot()
					if slot != null and not slot.is_empty():
						var stolen_item_name = slot.item.data.item_name if (slot.item and slot.item.data) else "Nieznany Przedmiot"
						print(attacker.name + " wytrąca przedmiot graczowi! (" + stolen_item_name + ")")
						inv.drop_current_item(true)
					else:
						if debug_mode: print("[StealItem] PUDŁO: Cel ma puste dłonie.")
				else:
					if debug_mode: print("[StealItem] PUDŁO: Cel nie posiada właściwej instancji Inventory.")
		else:
			if debug_mode: print("[StealItem] PUDŁO: Cel zdołał uciec z zasięgu!")
	else:
		if debug_mode: print("[StealItem] PUDŁO: Atakujący lub Cel zginęli.")

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false


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
		var alpha = clamp(1.0 - (elapsed / duration), 0.0, 1.0)
		var fill_color = Color(0.0, 1.0, 0.0, alpha * 0.2) if hit_success else Color(1.0, 0.0, 0.0, alpha * 0.2)
		var outline_color = Color(0.0, 1.0, 0.0, alpha * 0.8) if hit_success else Color(1.0, 0.0, 0.0, alpha * 0.8)
		
		draw_circle(Vector2.ZERO, radius, fill_color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, outline_color, 2.0)
		
		if target_pos != Vector2.ZERO:
			var local_target = to_local(target_pos)
			draw_line(Vector2.ZERO, local_target, outline_color, 2.0)
			draw_circle(local_target, 4.0, outline_color)
