extends AIAbility
class_name LaserVisionAbility

const CHARGE_PULSE_SPEED: float = 25.0
const MAX_LASER_HITS: int = 64

@export_group("Oprawa dźwiękowa")
## Dźwięk narastającego ładowania promienia.
@export var charge_feedback_cue: FeedbackCue = preload(
	"res://assets/data/feedback/enemies/laser_charge.tres"
)
## Dźwięk wystrzału po zakończeniu celowania.
@export var fire_feedback_cue: FeedbackCue = preload(
	"res://assets/data/feedback/enemies/laser_fire.tres"
)

@export_category("Zdolność: Laserowy Wzrok")

@export_group("Celowanie i Zasięg")
@export_range(0.1, 3.0, 0.1) var cast_time: float = 1.5
@export var laser_range: float = 2000.0
## Jeśli zaznaczone, promień celownika będzie wędrować za graczem w trakcie ładowania ataku.
@export var track_target_during_cast: bool = true
## Prędkość obrotu celownika za graczem w trakcie ładowania (0.01 - wolny, 1.0 - natychmiastowy).
@export_range(0.01, 1.0, 0.05) var tracking_smoothness: float = 0.05
## Czy laser ma podążać za graczem również W TRAKCIE strzelania?
@export var track_target_during_fire: bool = true
## Prędkość obrotu lasera podczas strzału (zazwyczaj wolniejsza, żeby gracz mógł przed nim uciec).
@export_range(0.005, 0.5, 0.005) var firing_tracking_smoothness: float = 0.01
## Maska fizyki dla ŚCIAN/PRZESZKÓD, na których laser ma się zatrzymać.
@export_flags_2d_physics var obstacles_mask: int = 1 

@export_group("Wizualizacje i Warstwy")
@export var laser_width: float = 15.0
@export var laser_color: Color = Color(1.0, 0.0, 0.0, 1.0)
## Czas, przez jaki fizycznie widać grubą wiązkę strzału (ciągły atak).
@export var laser_duration: float = 2.3
## Z-Index (warstwa rysowania) dla promienia lasera. Domyślnie 20 (nad postaciami).
@export var laser_z_index: int = GameLayers.HAZARD

@export_group("Obrażenia i Efekty")
## Obrażenia zadawane przy każdym "tiku" pobytu w laserze.
@export_range(1, 200, 1) var laser_damage_per_tick: int = 5
## Co ile sekund laser zadaje obrażenia, jeśli ofiara w nim stoi.
@export_range(0.1, 1.0, 0.1) var damage_tick_rate: float = 0.1
@export var friendly_fire: bool = true
@export var apply_burn_effect: bool = false
@export_range(1, 50, 1) var burn_damage_per_tick: int = 5
@export_range(1.0, 20.0, 0.5) var burn_duration: float = 3.0
## Siła wstrząsu kamery w trakcie strzelania (co każdy tik)
@export_range(0.0, 1.0, 0.05) var camera_trauma_amount: float = 0.15

func _init() -> void:
	ability_name = "Ciągły Przeszywający Laser"
	cooldown = 12.0
	min_range = 0.0
	max_range = 800.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	var sprite: CanvasItem = attacker.get_visual_sprite()
	var orig_modulate: Color = sprite.self_modulate if sprite != null else Color.WHITE

	var laser_node: LaserBeamVisual = LaserBeamVisual.new()
	laser_node.laser_width = laser_width
	laser_node.laser_color = laser_color
	laser_node.z_index = laser_z_index
	laser_node.z_as_relative = false
	if charge_feedback_cue != null:
		GameFeedback.play_cue(charge_feedback_cue, null, attacker.global_position, attacker)

	spawn_ability_node(attacker, laser_node, attacker.global_position)

	var elapsed: float = 0.0
	var aim_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state

	# =========================================================
	# FAZA 1: CELOWANIE I KUMULOWANIE ENERGII (BŁYSK)
	# =========================================================
	while elapsed < cast_time:
		if not is_instance_valid(attacker) or not attacker.is_inside_tree() or not is_instance_valid(target):
			if is_instance_valid(laser_node):
				laser_node.queue_free()
			if is_instance_valid(combat_ctrl):
				combat_ctrl.is_casting_ability = false
			if is_instance_valid(sprite):
				sprite.self_modulate = orig_modulate
			return

		if track_target_during_cast:
			var desired_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
			aim_dir = aim_dir.lerp(desired_dir, tracking_smoothness).normalized()
			orient_towards(attacker, aim_dir)

		var start_pos: Vector2 = attacker.global_position
		var max_end_pos: Vector2 = start_pos + (aim_dir * laser_range)

		var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start_pos, max_end_pos)
		ray_query.collision_mask = obstacles_mask
		ray_query.exclude = [attacker.get_rid()]
		var result: Dictionary = space_state.intersect_ray(ray_query)

		var end_pos: Vector2 = result["position"] if not result.is_empty() else max_end_pos
		laser_node.start_pos = start_pos
		laser_node.end_pos = end_pos

		var charge_progress: float = clampf(elapsed / maxf(0.01, cast_time), 0.0, 1.0)
		laser_node.charge_progress = charge_progress

		if is_instance_valid(sprite):
			var pulse: float = (sin(elapsed * CHARGE_PULSE_SPEED) + 1.0) / 2.0
			sprite.self_modulate = orig_modulate.lerp(laser_color, pulse * charge_progress)

		if not is_instance_valid(attacker) or not attacker.is_inside_tree():
			if is_instance_valid(laser_node):
				laser_node.queue_free()
			if is_instance_valid(sprite):
				sprite.self_modulate = orig_modulate
			return

		elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	if is_instance_valid(sprite):
		sprite.self_modulate = orig_modulate

	# =========================================================
	# FAZA 2: CIĄGŁY STRZAŁ Z ZADAWANIEM OBRAŻEŃ I KORYGOWANIEM
	# =========================================================
	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		if is_instance_valid(laser_node):
			laser_node.queue_free()
		return

	laser_node.phase = 1 
	if fire_feedback_cue != null:
		GameFeedback.play_cue(fire_feedback_cue, null, attacker.global_position, attacker)

	var fire_elapsed: float = 0.0
	var next_damage_tick: float = 0.0

	while fire_elapsed < laser_duration:
		if not is_instance_valid(attacker) or not attacker.is_inside_tree():
			if is_instance_valid(laser_node):
				laser_node.queue_free()
			return

		if track_target_during_fire and is_instance_valid(target):
			var desired_dir: Vector2 = attacker.global_position.direction_to(target.global_position)
			aim_dir = aim_dir.lerp(desired_dir, firing_tracking_smoothness).normalized()
			orient_towards(attacker, aim_dir)

		var start_pos: Vector2 = attacker.global_position
		var max_end_pos: Vector2 = start_pos + (aim_dir * laser_range)

		var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start_pos, max_end_pos)
		ray_query.collision_mask = obstacles_mask
		ray_query.exclude = [attacker.get_rid()]
		var ray_result: Dictionary = space_state.intersect_ray(ray_query)

		var final_end_pos: Vector2 = ray_result["position"] if not ray_result.is_empty() else max_end_pos
		laser_node.start_pos = start_pos
		laser_node.end_pos = final_end_pos

		if fire_elapsed >= next_damage_tick:
			next_damage_tick += damage_tick_rate

			var rect: RectangleShape2D = RectangleShape2D.new()
			var laser_length: float = start_pos.distance_to(final_end_pos)
			rect.size = Vector2(laser_length, laser_width)

			var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			shape_query.shape = rect
			var center: Vector2 = start_pos + (final_end_pos - start_pos) / 2.0
			shape_query.transform = Transform2D(aim_dir.angle(), center)
			shape_query.exclude = [attacker.get_rid()]

			var hits: Array[Dictionary] = space_state.intersect_shape(shape_query, MAX_LASER_HITS)

			var dmg_eff: DamageEffect = DamageEffect.new(laser_damage_per_tick)
			dmg_eff.effect_category = Effect.EffectCategory.FIRE_BURN
			var effects: Array[Effect] = [dmg_eff]

			if apply_burn_effect:
				var burn: PoisonDebuffEffect = PoisonDebuffEffect.new()
				burn.effect_name = "Podpalenie Lasera"
				# NAPRAWA KRYTYCZNA: Używamy hp_per_tick oraz kategorii FIRE_BURN!
				burn.hp_per_tick = -abs(burn_damage_per_tick)
				burn.duration = burn_duration
				burn.effect_category = Effect.EffectCategory.FIRE_BURN
				effects.append(burn)

			for hit in hits:
				var col: Node2D = hit["collider"] as Node2D
				if not is_instance_valid(col):
					continue
				if not friendly_fire and is_ally_of(attacker, col):
					continue
				if col.has_method("receive_effect"):
					for eff in effects:
						var cloned_eff: Effect = eff.duplicate(true)
						cloned_eff.source_entity = attacker
						cloned_eff.source_position = attacker.global_position
						col.receive_effect(cloned_eff)

			trigger_camera_shake(attacker, camera_trauma_amount)

		if not is_instance_valid(attacker) or not attacker.is_inside_tree():
			if is_instance_valid(laser_node):
				laser_node.queue_free()
			return

		fire_elapsed += attacker.get_physics_process_delta_time()
		await attacker.get_tree().physics_frame

	if is_instance_valid(laser_node):
		laser_node.queue_free()

	if is_instance_valid(attacker) and combat_ctrl != null:
		combat_ctrl.is_casting_ability = false

# ==============================================================================
# KLASA WEWNĘTRZNA: Zarządza dynamicznym rysowaniem wiązki
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
		var local_start: Vector2 = to_local(start_pos)
		var local_end: Vector2 = to_local(end_pos)

		if phase == 0:
			draw_line(local_start, local_end, Color(laser_color.r, laser_color.g, laser_color.b, 0.4), 2.0)
			var orb_radius: float = lerpf(2.0, laser_width * 2.5, charge_progress)
			var pulse_alpha: float = (sin(Time.get_ticks_msec() * 0.02) + 1.0) / 2.0
			var orb_color: Color = laser_color
			orb_color.a = lerpf(0.3, 0.9, pulse_alpha)
			draw_circle(local_start, orb_radius, orb_color)
			draw_circle(local_start, orb_radius * 0.5, Color.WHITE)
		elif phase == 1:
			draw_line(local_start, local_end, laser_color, laser_width)
			draw_line(local_start, local_end, Color.WHITE, laser_width * 0.4)
			draw_circle(local_start, laser_width * 1.8, laser_color)
			draw_circle(local_start, laser_width * 0.8, Color.WHITE)
			draw_circle(local_end, laser_width * 1.5, laser_color)
			draw_circle(local_end, laser_width * 0.6, Color.WHITE)
