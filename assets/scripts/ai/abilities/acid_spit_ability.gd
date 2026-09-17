extends AIAbility
class_name AcidSpitAbility

@export_category("Zdolność: Wirujący Deszcz Kwasu")

@export_group("Obrażenia i Kwas (Efekty)")
@export var impact_damage: int = 15
@export var poison_damage_per_tick: int = 5
@export var poison_duration: float = 6.0
@export var friendly_fire: bool = false

@export_group("Czas i Zasięg Ataku")
## [ZMNIEJSZONE] 6 sekund to optymalny czas uciekania
@export var barrage_duration: float = 6.0  
## [ZWIĘKSZONE] Daje graczowi czas na reakcję
@export var spawn_interval: float = 0.7      
## 1 plama leci w gracza, 4 tworzą wirujący wzór
@export var puddles_per_tick: int = 5        
## Promień giga-strefy
@export var barrage_radius: float = 1000.0   
## Promień pojedynczej plamy
@export var puddle_radius: float = 65.0      
## Czas zapalnika (musi być > spawn_interval)
@export var puddle_cast_time: float = 1.2    
## Predykcja ruchu gracza
@export var prediction_time: float = 0.7     

@export_group("Wizualizacje i Warstwy")
## Z-Index dla GIGA-OKRĘGU (wielkiej strefy). Domyślnie -20 (np. GameLayers.FLOOR)
@export var barrage_z_index: int = GameLayers.FLOOR_HAZARD
## Z-Index dla MAŁYCH PLAM. Domyślnie -15 (np. GameLayers.FLOOR_HAZARD)
@export var puddle_z_index: int = GameLayers.HAZARD
## Kolor wypełnienia wielkiej strefy zagrożenia (giga-okręgu)
@export var barrage_fill_color: Color = Color(0.82, 0.0, 0.329, 0.271)
## Kolor pulsującego obramowania wielkiej strefy
@export var barrage_outline_color: Color = Color(1.0, 0.0, 0.0, 0.6)
## Kolor małych plam (jeśli TelegraphedAOE obsługuje zmienną 'danger_color')
@export var puddle_danger_color: Color = Color(1.0, 0.624, 0.102, 0.612)

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

	# Tworzymy gigantyczną strefę zagrożenia
	var danger_zone = BarrageIndicator.new()
	danger_zone.radius = barrage_radius
	danger_zone.duration = barrage_duration
	danger_zone.fill_color = barrage_fill_color
	danger_zone.outline_color = barrage_outline_color
	danger_zone.z_index = barrage_z_index # <--- Z-INDEX DLA DUŻEGO KOŁA
	
	# BEZPIECZNE SPAWNOWANIE GIGA-STREFY W OPARCIU O MAPĘ
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", danger_zone, epicenter)
	else:
		var parent_node = attacker.get_parent()
		if parent_node:
			parent_node.add_child(danger_zone)
			danger_zone.global_position = epicenter
		else:
			attacker.get_tree().current_scene.add_child(danger_zone)
			danger_zone.global_position = epicenter

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
			
		# Zabezpieczenie, by plama nie wystawała POZA zielony okrąg
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

			# 4. SPAWNOWANIE AOE (Pojedynczej plamy)
			var aoe = TelegraphedAOE.new()
			var dmg_eff = DamageEffect.new(impact_damage)
			var poison_eff = PoisonEffect.new()
			poison_eff.duration = poison_duration
			poison_eff.poison_damage_per_tick = poison_damage_per_tick
			
			aoe.setup(drop_pos, puddle_radius, puddle_cast_time, [dmg_eff, poison_eff], attacker)
			aoe.friendly_fire = friendly_fire
			
			# Przypisanie warstwy i odcięcie relatywności względem rodzica (giga-okręgu)
			aoe.z_index = puddle_z_index # <--- Z-INDEX DLA MAŁYCH PLAM
			aoe.z_as_relative = false 
			
			if "danger_color" in aoe:
				aoe.danger_color = puddle_danger_color
			
			# DODAJEMY PLAMĘ JAKO DZIECKO GIGA-OKRĘGU (Trafia do poprawnej hierarchii)
			if is_instance_valid(danger_zone):
				danger_zone.add_child(aoe)
				aoe.global_position = drop_pos
			else:
				# Fallback bezpieczeństwa, gdyby z jakiegoś powodu giga-okrąg zniknął
				if attacker.has_signal("entity_spawn_requested"):
					attacker.emit_signal("entity_spawn_requested", aoe, drop_pos)
				else:
					attacker.get_tree().current_scene.add_child(aoe)
					aoe.global_position = drop_pos

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
	var fill_color: Color = Color(0.2, 0.8, 0.2, 0.1)
	var outline_color: Color = Color(0.2, 0.8, 0.2, 1.0)
	
	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		
		# Czekamy na upłynięcie głównego czasu
		if elapsed >= duration:
			# ZABEZPIECZENIE: Zanim zniszczymy Giga-Okrąg, upewniamy się, 
			# że wszystkie jego dzieci (małe plamy) zdążyły już wybuchnąć i same zniknęły.
			if get_child_count() == 0:
				queue_free()
			
	func _draw() -> void:
		# Giga-okrąg znika po określonym czasie, nawet jeśli czeka jeszcze na wybuch dzieci
		if elapsed >= duration:
			return
			
		draw_circle(Vector2.ZERO, radius, fill_color)
		var pulse = (sin(elapsed * 5.0) + 1.0) / 2.0 
		var alpha = lerp(0.3, 0.7, pulse)
		var final_outline = Color(outline_color.r, outline_color.g, outline_color.b, alpha)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, final_outline, 3.0)
