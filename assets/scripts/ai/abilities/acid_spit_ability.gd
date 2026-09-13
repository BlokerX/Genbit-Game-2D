extends AIAbility
class_name AcidSpitAbility

@export_category("Obrażenia i Kwas")
@export var impact_damage: int = 15
@export var poison_damage_per_tick: int = 5
@export var poison_duration: float = 6.0

@export_category("Czas i Zasięg Ataku")
@export var barrage_duration: float = 6.0    ## [ZMNIEJSZONE] 6 sekund to optymalny czas uciekania
@export var spawn_interval: float = 0.7      ## [ZWIĘKSZONE] Daje graczowi czas na reakcję
@export var puddles_per_tick: int = 5        ## 1 plama leci w gracza, 4 tworzą wirujący wzór
@export var barrage_radius: float = 1000.0    ## Promień giga-strefy
@export var puddle_radius: float = 65.0      ## Promień pojedynczej plamy
@export var puddle_cast_time: float = 1.2    ## Czas zapalnika (musi być > spawn_interval)
@export var prediction_time: float = 0.7     ## Predykcja ruchu gracza

func _init() -> void:
	ability_name = "Wirujący Deszcz Kwasu"
	cooldown = 15.0
	min_range = 0.0
	max_range = 600.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	# Pobieramy kontroler AI oraz jego profil zachowania
	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate: bool = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl:
		combat_ctrl.is_casting_ability = true

	# 1. ZAMROŻENIE EPICENTRUM
	var epicenter = target.global_position

	var danger_zone = BarrageIndicator.new()
	danger_zone.radius = barrage_radius
	danger_zone.duration = barrage_duration
	danger_zone.global_position = epicenter 
	attacker.get_tree().current_scene.add_child(danger_zone)

	var elapsed: float = 0.0
	var pattern_angle_offset: float = 0.0 

	while elapsed < barrage_duration:
		if not is_instance_valid(attacker) or not attacker.is_inside_tree() or not is_instance_valid(target):
			if is_instance_valid(danger_zone): danger_zone.queue_free()
			break

		# 2. PRZEWIDYWANIE RUCHU GRACZA
		var predicted_pos = target.global_position
		if "velocity" in target:
			predicted_pos += target.velocity * prediction_time
			
		# Zabezpieczenie, by czerwona plama nie wystawała POZA zielony okrąg
		var max_dist = barrage_radius - puddle_radius
		if epicenter.distance_to(predicted_pos) > max_dist:
			predicted_pos = epicenter + epicenter.direction_to(predicted_pos) * max_dist

		# ---------------------------------------------------------
		# [ZMODYFIKOWANA SEKCJA] OBRÓT ZALEŻNY OD PROFILU AI
		# ---------------------------------------------------------
		var aim_direction = attacker.global_position.direction_to(predicted_pos)
		
		if can_rotate:
			var target_angle = aim_direction.angle()
			attacker.rotation = lerp_angle(attacker.rotation, target_angle, 0.5)
		else:
			if attacker.has_method("_update_sprite_direction"):
				attacker._update_sprite_direction(aim_direction)
		# ---------------------------------------------------------

		# 3. TWORZENIE PLAM - GEOMETRYCZNY WZÓR
		for i in range(puddles_per_tick):
			var drop_pos = predicted_pos

			if i > 0:
				var fraction = float(i) / float(puddles_per_tick - 1) 
				var current_angle = (fraction * TAU) + pattern_angle_offset
				
				var ring_distance = max_dist * 0.8 if (int(elapsed * 10) % 2 == 0) else max_dist * 0.4
				drop_pos = epicenter + (Vector2.RIGHT.rotated(current_angle) * ring_distance)

			# 4. SPAWNOWANIE AOE
			var aoe = TelegraphedAOE.new()
			var dmg_eff = DamageEffect.new(impact_damage)
			var poison_eff = PoisonEffect.new()
			poison_eff.duration = poison_duration
			poison_eff.poison_damage_per_tick = poison_damage_per_tick
			
			aoe.setup(drop_pos, puddle_radius, puddle_cast_time, [dmg_eff, poison_eff], attacker)
			aoe.friendly_fire = false 
			attacker.get_tree().current_scene.add_child(aoe)

		pattern_angle_offset += PI / 4.0
		elapsed += spawn_interval
		await attacker.get_tree().create_timer(spawn_interval).timeout

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false

# ==============================================================================
# KLASA WEWNĘTRZNA: Giga-okrąg
# ==============================================================================
class BarrageIndicator extends Node2D:
	var radius: float = 0.0
	var duration: float = 0.0
	var elapsed: float = 0.0
	
	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()
			
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.2, 0.8, 0.2, 0.1))
		var pulse = (sin(elapsed * 5.0) + 1.0) / 2.0 
		var alpha = lerp(0.3, 0.7, pulse)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.2, 0.8, 0.2, alpha), 3.0)
