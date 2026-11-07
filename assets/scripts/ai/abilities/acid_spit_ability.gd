extends AIAbility
class_name AcidSpitAbility

const OUTER_RING_FACTOR: float = 0.8
const INNER_RING_FACTOR: float = 0.4
const PATTERN_ROTATION_STEP_RAD: float = PI / 4.0

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
## Z-Index dla GIGA-OKRĘGU (wielkiej strefy). Domyślnie -15 (np. GameLayers.FLOOR_HAZARD)
@export var barrage_z_index: int = GameLayers.FLOOR_HAZARD
## Z-Index dla MAŁYCH PLAM. Domyślnie 20 (np. GameLayers.HAZARD)
@export var puddle_z_index: int = GameLayers.HAZARD
## Kolor wypełnienia wielkiej strefy zagrożenia (giga-okrąg)
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
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	# Pobieramy kontroler walki AI i ustawiamy stan rzucania umiejętności
	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# 1. ZAMROŻENIE EPICENTRUM
	var epicenter: Vector2 = target.global_position

	# Tworzymy gigantyczną strefę zagrożenia
	var danger_zone: BarrageIndicator = BarrageIndicator.new()
	danger_zone.radius = barrage_radius
	danger_zone.duration = barrage_duration
	danger_zone.fill_color = barrage_fill_color
	danger_zone.outline_color = barrage_outline_color
	danger_zone.z_index = barrage_z_index # <--- Z-INDEX DLA DUŻEGO KOŁA

	# BEZPIECZNE SPAWNOWANIE GIGA-STREFY W OPARCIU O MAPĘ
	spawn_ability_node(attacker, danger_zone, epicenter)

	var elapsed: float = 0.0
	var pattern_angle_offset: float = 0.0 

	while elapsed < barrage_duration:
		if not is_instance_valid(attacker) or not attacker.is_inside_tree() or not is_instance_valid(target):
			if is_instance_valid(danger_zone):
				danger_zone.queue_free()
			break

		# 2. PRZEWIDYWANIE RUCHU GRACZA
		var predicted_pos: Vector2 = target.global_position
		if "velocity" in target:
			predicted_pos += target.velocity * prediction_time

		# Zabezpieczenie, by plama nie wystawała POZA zielony okrąg
		var max_dist: float = barrage_radius - puddle_radius
		if epicenter.distance_to(predicted_pos) > max_dist:
			predicted_pos = epicenter + epicenter.direction_to(predicted_pos) * max_dist

		# ---------------------------------------------------------
		# OBRÓT ZALEŻNY OD PROFILU AI (rotacyjny lub 8-kierunkowy)
		# ---------------------------------------------------------
		var aim_direction: Vector2 = attacker.global_position.direction_to(predicted_pos)
		orient_towards(attacker, aim_direction, 0.5)
		# ---------------------------------------------------------

		# 3. TWORZENIE PLAM - GEOMETRYCZNY WZÓR
		for i in range(puddles_per_tick):
			var drop_pos: Vector2 = predicted_pos

			if i > 0:
				var fraction: float = float(i) / float(maxi(1, puddles_per_tick - 1))
				var current_angle: float = (fraction * TAU) + pattern_angle_offset
				var ring_distance: float = max_dist * OUTER_RING_FACTOR if (int(elapsed * 10.0) % 2 == 0) else max_dist * INNER_RING_FACTOR
				drop_pos = epicenter + (Vector2.RIGHT.rotated(current_angle) * ring_distance)

			# 4. SPAWNOWANIE AOE (Pojedynczej plamy)
			var aoe: TelegraphedAOE = TelegraphedAOE.new()
			var dmg_eff: DamageEffect = DamageEffect.new(impact_damage)
			dmg_eff.effect_category = Effect.EffectCategory.POISON_ACID

			var poison_eff: PoisonDebuffEffect = PoisonDebuffEffect.new()
			poison_eff.duration = poison_duration
			poison_eff.hp_per_tick = -abs(poison_damage_per_tick)

			aoe.setup(drop_pos, puddle_radius, puddle_cast_time, [dmg_eff, poison_eff], attacker)
			aoe.friendly_fire = friendly_fire

			# Przypisanie warstwy i odcięcie relatywności względem rodzica (giga-okręgu)
			aoe.z_index = puddle_z_index # <--- Z-INDEX DLA MAŁYCH PLAM
			aoe.z_as_relative = false 
			aoe.danger_color = puddle_danger_color

			# DODAJEMY PLAMĘ JAKO DZIECKO GIGA-OKRĘGU (Trafia do poprawnej hierarchii)
			if is_instance_valid(danger_zone):
				danger_zone.add_child(aoe)
				aoe.global_position = drop_pos
			else:
				# Fallback bezpieczeństwa, gdyby z jakiegoś powodu giga-okrąg zniknął
				spawn_ability_node(attacker, aoe, drop_pos)

		pattern_angle_offset += PATTERN_ROTATION_STEP_RAD
		elapsed += spawn_interval

		# TARCZA: Bezwzględne sprawdzenie przed prośbą o get_tree()
		if not is_instance_valid(attacker) or not attacker.is_inside_tree():
			if is_instance_valid(danger_zone): 
				danger_zone.queue_free()
			break

		await attacker.get_tree().create_timer(spawn_interval).timeout

	if is_instance_valid(attacker) and combat_ctrl != null:
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
			# że wszystkie jego dzieci (małe plamy) zdążyły już wybuchnąć i same zniknąć!
			if get_child_count() == 0:
				queue_free()

	func _draw() -> void:
		# Giga-okrąg znika po określonym czasie, nawet jeśli czeka jeszcze na wybuch dzieci
		if elapsed >= duration:
			return

		draw_circle(Vector2.ZERO, radius, fill_color)
		var pulse: float = (sin(elapsed * 5.0) + 1.0) / 2.0 
		var alpha: float = lerpf(0.3, 0.7, pulse)
		var final_outline: Color = Color(outline_color.r, outline_color.g, outline_color.b, alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, final_outline, 3.0)
