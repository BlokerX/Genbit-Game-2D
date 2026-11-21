extends AIAbility
class_name JumpSmashAbility
## Uniwersalny archetyp telegrafowanego skoku z uderzeniem obszarowym przy lądowaniu (SOLID - SRP / OCP / DRY).
## Obrażenia, ogłuszenie, odrzut, kryt i penetracja pochodzą wyłącznie z AttackData, a dodatkowe skutki
## (np. zamrożenie, podpalenie, wstrząs kamery, wsparcie sojuszników) konfiguruje się w .tres przez on_hit_effects i components.

#region Stałe Domenowe (Brak magicznych liczb)
const HALF_DURATION_FACTOR: float = 0.5
const WALL_SAFETY_MARGIN_PX: float = 5.0
const DEFAULT_MIN_JUMP_RANGE: float = 50.0
const DEFAULT_MAX_JUMP_RANGE: float = 250.0
const LANDING_SPARK_COUNT: int = 10
const LANDING_SPARK_RADIUS_RATIO: float = 0.65
#endregion

@export_category("Archetyp: Miażdżący Skok (JumpSmashAbility)")

@export_group("Czas, Przewidywanie i Obszar Lądowania")
## Promień uderzenia przy lądowaniu (w pikselach).
@export_range(30.0, 600.0, 10.0) var aoe_radius: float = 80.0
## Całkowity czas od pojawienia się strefy ostrzegawczej do wylądowania i detonacji (w sekundach).
@export_range(0.2, 5.0, 0.05) var cast_time: float = 0.7
## Współczynnik przewidywania ruchu celu (0.0 = skacze w bieżącą pozycję, 1.0 = silne wyprzedzenie).
@export_range(0.0, 1.5, 0.1) var prediction_factor: float = 1.0
## Czas samego lotu w powietrzu (musi być mniejszy lub równy cast_time).
@export_range(0.1, 3.0, 0.05) var jump_duration: float = 0.4
## Czas odpoczynku rzucającego po wylądowaniu przed wznowieniem ruchu (w sekundach).
@export_range(0.0, 3.0, 0.05) var recovery_time: float = 0.8
## Jeśli true, trafienie przy lądowaniu działa wyłącznie na pierwotny cel (target). Jeśli false, działa na wszystkie cele w aoe_radius.
@export var hit_only_primary_target: bool = false
## Czy uderzenie przy lądowaniu ma ranić również sojuszników (gdy hit_only_primary_target == false)?
@export var friendly_fire: bool = false
## Warstwa fizyki dla ścian i przeszkód (chroni przed skokiem w ścianę).
@export_flags_2d_physics var obstacles_mask: int = 1

@export_group("Wizualizacje Skoku i Warstwy")
## Mnożnik powiększenia sylwetki w szczycie skoku (tworzy efekt wysokości lotu względem base_scale).
@export_range(1.0, 2.2, 0.05) var jump_peak_scale_multiplier: float = 1.35
## Warstwa renderowania (Z-Index) strefy ostrzegawczej na ziemi (domyślnie GameLayers.FLOOR_HAZARD).
@export var aoe_z_index: int = GameLayers.FLOOR_HAZARD
## Kolor plamy ostrzegawczej TelegraphedAOE oraz iskier przy lądowaniu.
@export var aoe_danger_color: Color = Color(1.0, 0.15, 0.10, 0.55)

func _init() -> void:
	ability_name = "Miażdżący Skok"
	cooldown = 8.0
	min_range = DEFAULT_MIN_JUMP_RANGE
	max_range = DEFAULT_MAX_JUMP_RANGE
	damage_category = Effect.EffectCategory.PHYSICAL_DAMAGE

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	# 1. Przewidywanie ruchu celu z limitem zasięgu max_range
	var predicted_pos: Vector2 = target.global_position
	if "velocity" in target and target.velocity != Vector2.ZERO:
		predicted_pos += target.velocity * prediction_factor

	if attacker.global_position.distance_to(predicted_pos) > max_range:
		predicted_pos = attacker.global_position + (attacker.global_position.direction_to(predicted_pos) * max_range)

	orient_towards(attacker, attacker.global_position.direction_to(predicted_pos))

	# 2. Wyznaczenie bezpiecznej pozycji lądowania (z uwzględnieniem rzeczywistego promienia bossa!)
	var effective_attacker_radius: float = CharacterEntity.get_effective_radius_of(attacker)
	var safe_target_pos: Vector2 = ItemPickup.calculate_safe_spawn_position(
		attacker.global_position,
		predicted_pos,
		attacker,
		obstacles_mask,
		effective_attacker_radius + WALL_SAFETY_MARGIN_PX
	)

	# 3. Strefa ostrzegawcza z efektami z jednolitego kontraktu AIAbility + callbacki komponentów
	var hit_effects: Array[Effect] = build_hit_effects(attacker)
	var aoe := TelegraphedAOE.new()
	var target_filter: Node2D = target if hit_only_primary_target else null
	aoe.setup(safe_target_pos, aoe_radius, cast_time, hit_effects, attacker, target_filter)
	aoe.friendly_fire = friendly_fire
	aoe.z_index = aoe_z_index
	aoe.z_as_relative = false
	aoe.danger_color = aoe_danger_color
	aoe.on_detonated_callback = func(origin_pos: Vector2, rad: float) -> void:
		notify_components_area_detonated(attacker, origin_pos, rad)
		CombatVFXHelper.spawn_impact_sparks(
			attacker,
			origin_pos,
			Vector2.ZERO,
			aoe_danger_color.lightened(0.35),
			LANDING_SPARK_COUNT,
			rad * LANDING_SPARK_RADIUS_RATIO
		)
	aoe.on_target_hit_callback = func(hit_target: Node2D, origin_pos: Vector2) -> void:
		notify_components_target_hit(attacker, hit_target, origin_pos)

	spawn_ability_node(attacker, aoe, safe_target_pos)

	# 4. Faza przygotowania przed odbiciem (windup)
	var clamped_jump_duration: float = minf(jump_duration, cast_time)
	var windup_time: float = maxf(0.0, cast_time - clamped_jump_duration)
	if windup_time > 0.0:
		await attacker.get_tree().create_timer(windup_time).timeout
		if not is_caster_active(attacker):
			_finish_cast(attacker, combat_ctrl)
			return

	# 5. Kinematyczny lot i bezpieczne skalowanie względem base_scale
	var reference_scale: Vector2 = attacker.base_scale
	var pos_tween: Tween = create_kinematic_dash_tween(
		attacker,
		safe_target_pos,
		clamped_jump_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	var scale_tween: Tween = attacker.create_tracked_tween()
	var half_jump_time: float = clamped_jump_duration * HALF_DURATION_FACTOR
	scale_tween.tween_property(attacker, "scale", reference_scale * jump_peak_scale_multiplier, half_jump_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(attacker, "scale", reference_scale, half_jump_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await pos_tween.finished

	if not is_caster_active(attacker):
		_finish_cast(attacker, combat_ctrl)
		return

	# Gwarantujemy powrót do idealnej skali bazowej po wylądowaniu
	attacker.reset_visual_scale()

	# 6. Faza odpoczynku po skoku (recovery)
	if recovery_time > 0.0:
		await attacker.get_tree().create_timer(recovery_time).timeout

	_finish_cast(attacker, combat_ctrl)

## Bezpiecznie kończy rzucanie skoku (parametry Variant chronią przed błędem 'previously freed' po await).
func _finish_cast(attacker: Variant, combat_ctrl: Variant) -> void:
	if is_instance_valid(attacker) and attacker is CharacterEntity:
		(attacker as CharacterEntity).reset_visual_scale()
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)
