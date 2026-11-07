extends AIAbility
class_name JumpSmashAbility

const JUMP_SCALE_MULTIPLIER: float = 1.35
const HALF_DURATION_FACTOR: float = 0.5
const WALL_SAFETY_MARGIN_PX: float = 5.0

@export_category("Zdolność: Miażdżący Skok")
@export_group("Obrażenia i Efekty")
@export var damage: int = 30
@export var stun_duration: float = 1.5
## Siła odrzutu
@export var knockback_force: float = 800.0 

@export_group("Czas i Zasięg Ataku")
@export var aoe_radius: float = 80.0
## Całkowity czas od momentu narysowania plamy do wybuchu
@export var cast_time: float = 0.7      
## Czas (w sekundach), z jakim boss przewiduje ruch gracza (0.0 = skacze w miejsce, 1.0 = skacze mocno do przodu)
@export_range(0.0, 1.5, 0.1) var prediction_factor: float = 1.0
## Czas samego lotu (zawsze musi być mniejszy niż cast_time!)
@export var jump_duration: float = 0.4
## Odpoczynek bossa po skoku
@export var recovery_time: float = 0.8
## Warstwa fizyki, na której są ściany
@export_flags_2d_physics var obstacles_mask: int = 1

@export_group("Wizualizacje i Warstwy")
## Z-Index (warstwa rysowania) dla plamy na ziemi. Domyślnie -15 (pod postaciami).
@export var aoe_z_index: int = -15
## Kolor plamy ostrzegawczej (TelegraphedAOE)
@export var aoe_danger_color: Color = Color(1.0, 0.0, 0.0, 0.5)
## Siła wstrząsu kamery przy uderzeniu o ziemię
@export_range(0.0, 1.0, 0.1) var camera_trauma_amount: float = 0.4

func _init() -> void:
	ability_name = "Miażdżący Skok"
	cooldown = 8.0
	min_range = 50.0
	max_range = 250.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# --- 1. PRZEWIDYWANIE RUCHU CELU ---
	var predicted_pos: Vector2 = target.global_position
	if "velocity" in target and target.velocity != Vector2.ZERO:
		predicted_pos += target.velocity * prediction_factor

	var dist_to_prediction: float = attacker.global_position.distance_to(predicted_pos)
	if dist_to_prediction > max_range:
		predicted_pos = attacker.global_position + attacker.global_position.direction_to(predicted_pos) * max_range

	# --- 2. WYLICZANIE BEZPIECZNEJ POZYCJI LĄDOWANIA ---
	var attacker_rad: float = attacker.combat_radius
	var safe_target_pos: Vector2 = ItemPickup.calculate_safe_spawn_position(
		attacker.global_position,
		predicted_pos,
		attacker,
		obstacles_mask,
		attacker_rad + WALL_SAFETY_MARGIN_PX
	)

	# --- 3. SPAWNOWANIE PLAMY OSTRZEGAWCZEJ ---
	var aoe: TelegraphedAOE = TelegraphedAOE.new()
	var dmg_eff: DamageEffect = DamageEffect.new(damage)
	var stun_eff: StunEffect = StunEffect.new(stun_duration)
	var knock_eff: KnockbackEffect = KnockbackEffect.new(knockback_force)

	aoe.setup(safe_target_pos, aoe_radius, cast_time, [dmg_eff, stun_eff, knock_eff], attacker, target)
	aoe.z_index = aoe_z_index
	aoe.z_as_relative = false
	aoe.danger_color = aoe_danger_color

	spawn_ability_node(attacker, aoe, safe_target_pos)

	var windup_time: float = maxf(0.0, cast_time - jump_duration)
	if windup_time > 0.0:
		if not is_instance_valid(attacker) or not attacker.is_inside_tree():
			return
		await attacker.get_tree().create_timer(windup_time).timeout

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	# --- 4. KINEMATYCZNY LOT I BEZPIECZNE SKALOWANIE WZGLĘDEM BASE_SCALE ---
	var reference_scale: Vector2 = attacker.base_scale
	var pos_tween: Tween = create_kinematic_dash_tween(
		attacker,
		safe_target_pos,
		jump_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

	var scale_tween: Tween = attacker.create_tracked_tween()
	var half_jump_time: float = jump_duration * HALF_DURATION_FACTOR
	scale_tween.tween_property(attacker, "scale", reference_scale * JUMP_SCALE_MULTIPLIER, half_jump_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(attacker, "scale", reference_scale, half_jump_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return
	await pos_tween.finished

	if not is_instance_valid(attacker):
		return
	# Gwarantujemy powrót do idealnej skali bazowej po wylądowaniu!
	attacker.reset_visual_scale()

	if not attacker.is_inside_tree():
		return

	# Wstrząs kamery przy uderzeniu o ziemię (naprawiony!)
	trigger_camera_shake(attacker, camera_trauma_amount)

	if recovery_time > 0.0:
		await attacker.get_tree().create_timer(recovery_time).timeout

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	if combat_ctrl != null:
		combat_ctrl.is_casting_ability = false
