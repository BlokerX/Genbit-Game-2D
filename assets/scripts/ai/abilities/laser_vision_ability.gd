extends AIAbility
class_name LaserVisionAbility

@export_category("Zdolność: Laserowy Wzrok")

@export_group("Celowanie i Zasięg")
@export_range(0.1, 3.0, 0.1) var cast_time: float = 1.5
@export var laser_range: float = 2000.0
## Jeśli zaznaczone, promień celownika będzie wędrował za graczem w trakcie ładowania ataku.
@export var track_target_during_cast: bool = true
## Prędkość obrotu celownika za graczem w trakcie ładowania (0.01 - wolny, 1.0 - natychmiastowy).
@export_range(0.01, 1.0, 0.05) var tracking_smoothness: float = 0.05
## Czy laser ma podążać za graczem również W TRAKCIE strzelania?
@export var track_target_during_fire: bool = true
## Prędkość obrotu lasera podczas strzału (zazwyczaj wolniejsza, żeby gracz mógł przed nim uciec).
@export_range(0.005, 0.5, 0.005) var firing_tracking_smoothness: float = 0.01
## Maska fizyki dla ŚCIAN/PRZESZKÓD, na których laser ma się zatrzymać.
@export_flags_2d_physics var obstacles_mask: int = 1 

@export_group("Wizualizacje Lasera")
@export var laser_width: float = 15.0
@export var laser_color: Color = Color.RED
## Czas, przez jaki fizycznie widać grubą wiązkę strzału (ciągły atak).
@export var laser_duration: float = 2.3

@export_group("Obrażenia i Efekty")
## Obrażenia zadawane przy każdym "tiku" pobytu w laserze.
@export_range(1, 200, 1) var laser_damage_per_tick: int = 5
## Co ile sekund laser zadaje obrażenia, jeśli ofiara w nim stoi.
@export_range(0.1, 1.0, 0.1) var damage_tick_rate: float = 0.1
@export var friendly_fire: bool = false
@export var apply_burn_effect: bool = false
@export_range(1, 50, 1) var burn_damage_per_tick: int = 5
@export_range(1.0, 20.0, 0.5) var burn_duration: float = 3.0

func _init() -> void:
	ability_name = "Ciągły Przeszywający Laser"
	cooldown = 12.0
	min_range = 0.0
	max_range = 800.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl: combat_ctrl.is_casting_ability = true

	var sprite = attacker.get_node_or_null("Sprite2D")
	if attacker.get("character_sprite"): sprite = attacker.character_sprite
	var orig_modulate = Color.WHITE
	if sprite: orig_modulate = sprite.self_modulate

	var laser_node = LaserBeamVisual.new()
	laser_node.laser_width = laser_width
	laser_node.laser_color = laser_color
	attacker.get_tree().current_scene.add_child(laser_node)

	var elapsed: float = 0.0
	var aim_dir = attacker.global_position.direction_to(target.global_position)
	var space_state = attacker.get_world_2d().direct_space_state

	# =========================================================
	# FAZA 1: CELOWANIE I KUMULOWANIE ENERGII (BŁYSK)
	# =========================================================
	while elapsed < cast_time:
		if not is_instance_valid(attacker) or not is_instance_valid(target):
			if is_instance_valid(laser_node): laser_node.queue_free()
			if is_instance_valid(combat_ctrl): combat_ctrl.is_casting_ability = false
			if sprite and is_instance_valid(sprite): sprite.self_modulate = orig_modulate
			return

		if track_target_during_cast:
			var desired_dir = attacker.global_position.direction_to(target.global_position)
			aim_dir = aim_dir.lerp(desired_dir, tracking_smoothness).normalized()

			if can_rotate:
				attacker.rotation = aim_dir.angle()
			elif attacker.has_method("_update_sprite_direction"):
				attacker._update_sprite_direction(aim_dir)
		
		var start_pos = attacker.global_position
		var max_end_pos = start_pos + (aim_dir * laser_range)
		
		var ray_query = PhysicsRayQueryParameters2D.create(start_pos, max_end_pos)
		ray_query.collision_mask = obstacles_mask
		ray_query.exclude = [attacker.get_rid()]
		
		var result = space_state.intersect_ray(ray_query)
		var end_pos = result.position if result else max_end_pos

		laser_node.start_pos = start_pos
		laser_node.end_pos = end_pos
		var charge_progress = clamp(elapsed / cast_time, 0.0, 1.0)
		laser_node.charge_progress = charge_progress
		
		if sprite:
			var pulse = (sin(elapsed * 25.0) + 1.0) / 2.0
			sprite.self_modulate = orig_modulate.lerp(laser_color, pulse * charge_progress)

		elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	if sprite and is_instance_valid(sprite): sprite.self_modulate = orig_modulate

	# =========================================================
	# FAZA 2: CIĄGŁY STRZAŁ Z ZADAWANIEM OBRAŻEŃ I KORYGOWANIEM
	# =========================================================
	if not is_instance_valid(attacker):
		if is_instance_valid(laser_node): laser_node.queue_free()
		return

	laser_node.phase = 1 
	
	var fire_elapsed: float = 0.0
	var next_damage_tick: float = 0.0

	while fire_elapsed < laser_duration:
		if not is_instance_valid(attacker):
			if is_instance_valid(laser_node): laser_node.queue_free()
			return

		# Śledzenie gracza w trakcie strzału (powolne zamiatanie laserem)
		if track_target_during_fire and is_instance_valid(target):
			var desired_dir = attacker.global_position.direction_to(target.global_position)
			aim_dir = aim_dir.lerp(desired_dir, firing_tracking_smoothness).normalized()

			if can_rotate:
				attacker.rotation = aim_dir.angle()
			elif attacker.has_method("_update_sprite_direction"):
				attacker._update_sprite_direction(aim_dir)

		var start_pos = attacker.global_position
		var max_end_pos = start_pos + (aim_dir * laser_range)
		
		# Ciągłe sprawdzanie kolizji ze ścianą (żeby laser gładko zsuwał się po kątach)
		var ray_query = PhysicsRayQueryParameters2D.create(start_pos, max_end_pos)
		ray_query.collision_mask = obstacles_mask
		ray_query.exclude = [attacker.get_rid()]
		var ray_result = space_state.intersect_ray(ray_query)
		var final_end_pos = ray_result.position if ray_result else max_end_pos
		
		laser_node.start_pos = start_pos
		laser_node.end_pos = final_end_pos

		# Co ułamek sekundy (damage_tick_rate) zadajemy obrażenia wszystkiemu w świetle
		if fire_elapsed >= next_damage_tick:
			next_damage_tick += damage_tick_rate

			var rect = RectangleShape2D.new()
			var laser_length = start_pos.distance_to(final_end_pos)
			rect.size = Vector2(laser_length, laser_width)

			var shape_query = PhysicsShapeQueryParameters2D.new()
			shape_query.shape = rect
			var center = start_pos + (final_end_pos - start_pos) / 2.0
			shape_query.transform = Transform2D(aim_dir.angle(), center)
			shape_query.exclude = [attacker.get_rid()]
			
			var hits = space_state.intersect_shape(shape_query, 64)
			
			var effects: Array[Effect] = [DamageEffect.new(laser_damage_per_tick)]
			if apply_burn_effect:
				var burn = PoisonEffect.new()
				burn.effect_name = "Podpalenie Lasera"
				burn.poison_damage_per_tick = burn_damage_per_tick
				burn.duration = burn_duration
				effects.append(burn)

			for hit in hits:
				var col = hit.collider
				if not is_instance_valid(col): continue
				if not friendly_fire and _is_ally(attacker, col as Node2D): continue

				if col.has_method("receive_effect"):
					for eff in effects:
						var cloned_eff = eff.duplicate(true)
						cloned_eff.source_entity = attacker
						cloned_eff.source_position = attacker.global_position
						col.receive_effect(cloned_eff)

			# Lekkie, cykliczne drżenie kamery potęgujące wagę trwającego ataku
			var cam = attacker.get_tree().current_scene.get_node_or_null("CameraComponent")
			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(0.15)

		fire_elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	if is_instance_valid(laser_node):
		laser_node.queue_free()

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false


func _is_ally(attacker: Node2D, target: Node2D) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return false
	var attacker_faction = attacker.get_node_or_null("FactionComponent")
	if attacker_faction and target is CharacterEntity:
		return attacker_faction.get_disposition_toward(target) == FactionComponent.Disposition.FRIENDLY
	return false

# ==============================================================================
# KLASA WEWNĘTRZNA: Zarządza dynamicznym rysowaniem
# ==============================================================================
class LaserBeamVisual extends Node2D:
	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2.ZERO
	var laser_width: float = 15.0
	var laser_color: Color = Color.RED
	var phase: int = 0
	var charge_progress: float = 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var local_start = to_local(start_pos)
		var local_end = to_local(end_pos)
		
		if phase == 0:
			draw_line(local_start, local_end, Color(laser_color.r, laser_color.g, laser_color.b, 0.4), 2.0)
			
			var orb_radius = lerp(2.0, laser_width * 2.5, charge_progress)
			var pulse_alpha = (sin(Time.get_ticks_msec() * 0.02) + 1.0) / 2.0
			var orb_color = laser_color
			orb_color.a = lerp(0.3, 0.9, pulse_alpha)
			
			draw_circle(local_start, orb_radius, orb_color)
			draw_circle(local_start, orb_radius * 0.5, Color.WHITE)
			
		elif phase == 1:
			draw_line(local_start, local_end, laser_color, laser_width)
			draw_line(local_start, local_end, Color.WHITE, laser_width * 0.4)
			
			draw_circle(local_start, laser_width * 1.8, laser_color)
			draw_circle(local_start, laser_width * 0.8, Color.WHITE)
			
			draw_circle(local_end, laser_width * 1.5, laser_color)
			draw_circle(local_end, laser_width * 0.6, Color.WHITE)
