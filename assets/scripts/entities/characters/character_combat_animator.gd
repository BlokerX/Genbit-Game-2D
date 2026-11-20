class_name CharacterCombatAnimator
extends RefCounted
## Kontroler proceduralnych animacji walki, ruchu trzymanej broni, uderzeń wręcz,
## reakcji na obrażenia oraz zielonego podświetlenia leczenia (SOLID - SRP / DRY).
## Działa wyłącznie na węzłach wizualnych (character_sprite oraz HeldItemVisual), nie zakłócając fizyki CharacterBody2D.

#region Stałe Parametrów Animacji Bojowych (Brak magicznych liczb)
## Minimalny kwadrat prędkości wymagany do wyznaczenia kierunku z wektora ruchu.
const MIN_DIRECTION_VELOCITY_SQ: float = 1.0

## Dystans wizualnego wypadu ciała podczas uderzenia wręcz / gołą pięścią (w pikselach).
const UNARMED_LUNGE_DISTANCE_PX: float = 16.0
## Czas fazy uderzenia w przód przy ataku wręcz (w sekundach).
const UNARMED_STRIKE_IN_DURATION_SEC: float = 0.07
## Czas fazy powrotu po uderzeniu wręcz (w sekundach).
const UNARMED_STRIKE_OUT_DURATION_SEC: float = 0.14
## Mnożnik rozciągnięcia sprite'a w osi ruchu podczas wypadu wręcz (Squash & Stretch).
const UNARMED_STRETCH_SCALE := Vector2(1.14, 0.90)

## Dystans krótkiego kroku ciała podczas zamachu bronią białą (w pikselach).
const MELEE_BODY_STEP_PX: float = 10.0
## Kąt początkowy zamachu bronią białą względem kierunku celu (w radianach).
const MELEE_SWING_START_ANGLE_RAD: float = -1.15
## Kąt końcowy zamachu bronią białą względem kierunku celu (w radianach).
const MELEE_SWING_END_ANGLE_RAD: float = 1.20
## Dodatkowe wysunięcie broni białej w stronę celu w szczycie zamachu (w pikselach).
const MELEE_THRUST_REACH_PX: float = 14.0
## Ułamek czasu zamachu przeznaczony na fazę wysunięcia ostrza w przód.
const MELEE_THRUST_TIME_RATIO: float = 0.60
## Czas trwania głównego cięcia bronią białą (w sekundach).
const MELEE_SWING_DURATION_SEC: float = 0.11
## Czas powrotu broni białej do pozycji spoczynkowej (w sekundach).
const MELEE_RECOVERY_DURATION_SEC: float = 0.14
## Mnożnik skali broni białej w szczycie zamachu.
const MELEE_WEAPON_PEAK_SCALE_MULT: float = 1.22

## Dystans cofnięcia broni palnej przy odrzucie wystrzału (w pikselach).
const RANGED_WEAPON_RECOIL_PX: float = 9.0
## Kąt podbicia lufy broni palnej podczas wystrzału (w radianach).
const RANGED_MUZZLE_CLIMB_RAD: float = 0.28
## Dystans lekkiego cofnięcia korpusu strzelca przy wystrzale (w pikselach).
const RANGED_BODY_RECOIL_PX: float = 4.0
## Czas fazy odrzutu broni palnej (w sekundach).
const RANGED_KICK_DURATION_SEC: float = 0.05
## Czas powrotu broni palnej po odrzucie (w sekundach).
const RANGED_RECOVER_DURATION_SEC: float = 0.13

## Dystans zamachu ciała podczas rzutu przedmiotem (w pikselach).
const THROW_BODY_LEAN_PX: float = 11.0
## Kąt obrotu dłoni podczas wyrzutu przedmiotu (w radianach).
const THROW_SPIN_ANGLE_RAD: float = 0.95
## Czas fazy wyrzutu przedmiotu (w sekundach).
const THROW_SNAP_DURATION_SEC: float = 0.08
## Czas powrotu po rzucie (w sekundach).
const THROW_RECOVER_DURATION_SEC: float = 0.14

## Dystans wizualnego odskoku (flinch) sprite'a postaci po otrzymaniu obrażeń (w pikselach).
const HIT_FLINCH_DISTANCE_PX: float = 9.0
## Mnożnik spłaszczenia sprite'a w momencie przyjęcia ciosu.
const HIT_SQUASH_SCALE := Vector2(1.16, 0.86)
## Czas odskoku przy trafieniu (w sekundach).
const HIT_JOLT_IN_DURATION_SEC: float = 0.05
## Czas powrotu do równowagi po trafieniu (w sekundach).
const HIT_JOLT_OUT_DURATION_SEC: float = 0.15
## Kolor krótkiego rozbłysku sprite'a w chwili przyjęcia obrażeń.
const HIT_FLASH_MODULATE := Color(1.85, 0.45, 0.45, 1.0)

## Kolor jasnego zielonego podświetlenia sprite'a przy pełnym leczeniu (np. mikstura / apteczka).
const HEAL_FLASH_MODULATE := Color(0.45, 1.85, 0.65, 1.0)
## Kolor łagodniejszego zielonego impulsu sprite'a przy tiku regeneracji w czasie.
const HEAL_SUBTLE_FLASH_MODULATE := Color(0.65, 1.45, 0.78, 1.0)
## Czas wygaszania zielonego podświetlenia dla pełnego leczenia (w sekundach).
const HEAL_FLASH_DURATION_SEC: float = 0.28
## Czas wygaszania zielonego podświetlenia dla tiku regeneracji (w sekundach).
const HEAL_SUBTLE_FLASH_DURATION_SEC: float = 0.22
## Lekkie uniesienie sprite'a w górę podczas pełnego leczenia (w pikselach).
const HEAL_LIFT_DISTANCE_PX: float = 6.0
## Delikatne uniesienie sprite'a przy tiku regeneracji (w pikselach).
const HEAL_SUBTLE_LIFT_DISTANCE_PX: float = 2.5
## Sprężyste wydłużenie pionowe sprite'a w chwili uleczenia.
const HEAL_STRETCH_SCALE := Vector2(0.94, 1.08)
## Delikatna skala dla tiku regeneracji.
const HEAL_SUBTLE_STRETCH_SCALE := Vector2(0.98, 1.03)
## Czas fazy uniesienia sprite'a przy leczeniu (w sekundach).
const HEAL_LIFT_IN_DURATION_SEC: float = 0.10
## Czas fazy powrotu sprite'a po leczeniu (w sekundach).
const HEAL_LIFT_OUT_DURATION_SEC: float = 0.20

## Parametry efektów cząsteczkowych smug i błysków bojowych (Brak magicznych liczb).
const STRIKE_ARC_OFFSET_PX: float = 26.0
const UNARMED_ARC_RADIUS_PX: float = 20.0
const MELEE_ARC_RADIUS_PX: float = 34.0
const STRIKE_ARC_DURATION_SEC: float = 0.16
const STRIKE_ARC_POINTS: int = 20
const UNARMED_ARC_COLOR := Color(1.0, 0.95, 0.80, 0.85)
const MELEE_ARC_COLOR := Color(0.90, 0.96, 1.0, 0.92)
const MUZZLE_FLASH_COLOR := Color(1.0, 0.88, 0.35, 0.95)
const MUZZLE_FLASH_RADIUS_PX: float = 10.0
const MUZZLE_FLASH_OFFSET_PX: float = 22.0

## Parametry proceduralnej poświaty i unoszących się plusów leczenia (powiększone, czytelne na każdej sylwetce).
const HEAL_VFX_DURATION_SEC: float = 0.58
const HEAL_VFX_SUBTLE_DURATION_SEC: float = 0.45
const HEAL_VFX_BASE_RADIUS_PX: float = 38.0
const HEAL_VFX_COMBAT_RADIUS_RATIO: float = 0.95
const HEAL_VFX_RING_COLOR := Color(0.28, 0.98, 0.50, 0.88)
const HEAL_VFX_HALO_COLOR := Color(0.35, 1.0, 0.60, 0.20)
const HEAL_VFX_PLUS_COLOR := Color(0.82, 1.0, 0.86, 0.98)
const HEAL_VFX_PLUS_OUTLINE_COLOR := Color(0.05, 0.35, 0.12, 0.90)
const HEAL_VFX_FULL_PARTICLE_COUNT: int = 6
const HEAL_VFX_SUBTLE_PARTICLE_COUNT: int = 4
#endregion

var _character: CharacterEntity = null
var _base_sprite_pos: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_held_pos: Vector2 = Vector2.ZERO
var _base_held_scale: Vector2 = Vector2.ONE
var _has_cached_held_rest_pose: bool = false

## Oddzielne kanały Tweenów (SRP): ciało, broń oraz kolor podświetlenia nigdy ze sobą nie kolidują.
var _body_tween: Tween = null
var _weapon_tween: Tween = null
var _color_flash_tween: Tween = null
var _swing_parity: float = 1.0

## Inicjalizuje animator dla wskazanej postaci i zapamiętuje pozycję spoczynkową jej węzłów wizualnych.
func initialize(character: CharacterEntity) -> void:
	_character = character
	if not is_instance_valid(_character):
		return
	var sprite: Node2D = _character.get_visual_sprite() as Node2D
	if sprite != null:
		_base_sprite_pos = sprite.position
		_base_sprite_scale = sprite.scale
	_cache_held_item_rest_pose()

func _cache_held_item_rest_pose() -> void:
	if _has_cached_held_rest_pose or not is_instance_valid(_character):
		return
	var held_vis: Node2D = _get_held_item_visual()
	if held_vis != null:
		_base_held_pos = held_vis.position
		_base_held_scale = held_vis.scale
		_has_cached_held_rest_pose = true

func _get_held_item_visual() -> Sprite2D:
	if not is_instance_valid(_character):
		return null
	if "held_item_visual" in _character and _character.get("held_item_visual") is Sprite2D:
		return _character.get("held_item_visual") as Sprite2D
	return _character.get_node_or_null("HeldItemHandler/HeldItemVisual") as Sprite2D

## Natychmiast przerywa aktywne animacje ruchu oraz koloru i przywraca domyślne ułożenie sprite'a oraz dłoni.
func reset_pose() -> void:
	_kill_tween(_body_tween)
	_kill_tween(_weapon_tween)
	_kill_tween(_color_flash_tween)
	if not is_instance_valid(_character):
		return

	var sprite: Node2D = _character.get_visual_sprite() as Node2D
	if sprite != null:
		sprite.position = _base_sprite_pos
		sprite.scale = _base_sprite_scale
		if _can_flash_sprite_color():
			sprite.self_modulate = Color.WHITE

	var held_vis: Sprite2D = _get_held_item_visual()
	if held_vis != null and _has_cached_held_rest_pose:
		held_vis.position = _base_held_pos
		held_vis.scale = _base_held_scale
		held_vis.rotation = 0.0
		held_vis.flip_v = false

# =========================================================================
# 1. ATAK RĘCZNY / GOŁĄ PIĘŚCIĄ / PAZURAMI (Gracz i Przeciwnicy)
# =========================================================================

## Odtwarza dynamiczny wypad ciała (lunge) oraz smugę uderzenia wręcz w stronę celu.
func play_unarmed_strike(target_world_pos: Vector2) -> void:
	if not _can_animate():
		return

	var attack_dir: Vector2 = _resolve_direction_to(target_world_pos)
	_orient_character_towards(attack_dir)

	var local_dir: Vector2 = attack_dir.rotated(-_character.global_rotation)
	_animate_body_motion(
		local_dir * UNARMED_LUNGE_DISTANCE_PX,
		UNARMED_STRETCH_SCALE,
		UNARMED_STRIKE_IN_DURATION_SEC,
		UNARMED_STRIKE_OUT_DURATION_SEC,
		Tween.TRANS_BACK
	)
	_spawn_procedural_strike_arc(attack_dir, UNARMED_ARC_RADIUS_PX, UNARMED_ARC_COLOR, false)

# =========================================================================
# 2. ATAK BRONIĄ BIAŁĄ (Zamach po łuku + Smuga cięcia)
# =========================================================================

## Odtwarza szeroki zamach trzymaną bronią białą po łuku wraz z krokiem natarcia i smugą ostrza.
func play_melee_swing(target_world_pos: Vector2) -> void:
	if not _can_animate():
		return

	_cache_held_item_rest_pose()
	var attack_dir: Vector2 = _resolve_direction_to(target_world_pos)
	_orient_character_towards(attack_dir)

	var local_dir: Vector2 = attack_dir.rotated(-_character.global_rotation)
	_animate_body_motion(
		local_dir * MELEE_BODY_STEP_PX,
		UNARMED_STRETCH_SCALE,
		MELEE_SWING_DURATION_SEC,
		MELEE_RECOVERY_DURATION_SEC,
		Tween.TRANS_BACK
	)
	_spawn_procedural_strike_arc(attack_dir, MELEE_ARC_RADIUS_PX, MELEE_ARC_COLOR, false)

	var held_vis: Sprite2D = _get_held_item_visual()
	if held_vis == null or not held_vis.visible:
		return

	_kill_tween(_weapon_tween)
	_swing_parity = -_swing_parity

	var base_angle: float = local_dir.angle()
	var start_angle: float = base_angle + (MELEE_SWING_START_ANGLE_RAD * _swing_parity)
	var end_angle: float = base_angle + (MELEE_SWING_END_ANGLE_RAD * _swing_parity)
	var thrust_pos: Vector2 = _base_held_pos + (local_dir * MELEE_THRUST_REACH_PX)

	held_vis.position = _base_held_pos
	held_vis.rotation = start_angle
	held_vis.scale = _base_held_scale * MELEE_WEAPON_PEAK_SCALE_MULT

	_weapon_tween = _character.create_tracked_tween()
	_weapon_tween.set_parallel(true)
	_weapon_tween.tween_property(held_vis, "rotation", end_angle, MELEE_SWING_DURATION_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(held_vis, "position", thrust_pos, MELEE_SWING_DURATION_SEC * MELEE_THRUST_TIME_RATIO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.chain().set_parallel(true)
	_weapon_tween.tween_property(held_vis, "position", _base_held_pos, MELEE_RECOVERY_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_weapon_tween.tween_property(held_vis, "rotation", 0.0, MELEE_RECOVERY_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_weapon_tween.tween_property(held_vis, "scale", _base_held_scale, MELEE_RECOVERY_DURATION_SEC)

# =========================================================================
# 3. STRZAŁ Z BRONI PALNEJ (Odrzut lufy + Błysk wystrzału)
# =========================================================================

## Odtwarza odrzut trzymanej broni palnej (recoil kickback), lekki odrzut korpusu oraz błysk lufy.
func play_ranged_recoil(target_world_pos: Vector2) -> void:
	if not _can_animate():
		return

	_cache_held_item_rest_pose()
	var fire_dir: Vector2 = _resolve_direction_to(target_world_pos)
	_orient_character_towards(fire_dir)

	var local_dir: Vector2 = fire_dir.rotated(-_character.global_rotation)
	_animate_body_motion(
		-local_dir * RANGED_BODY_RECOIL_PX,
		Vector2.ONE,
		RANGED_KICK_DURATION_SEC,
		RANGED_RECOVER_DURATION_SEC,
		Tween.TRANS_BACK
	)
	_spawn_procedural_strike_arc(fire_dir, MUZZLE_FLASH_RADIUS_PX, MUZZLE_FLASH_COLOR, true)

	var held_vis: Sprite2D = _get_held_item_visual()
	if held_vis == null or not held_vis.visible:
		return

	_kill_tween(_weapon_tween)
	var aim_angle: float = local_dir.angle()
	var is_aiming_left: bool = local_dir.x < 0.0
	held_vis.flip_v = is_aiming_left
	var climb_sign: float = 1.0 if is_aiming_left else -1.0

	var recoil_pos: Vector2 = _base_held_pos - (local_dir * RANGED_WEAPON_RECOIL_PX)
	var recoil_angle: float = aim_angle + (RANGED_MUZZLE_CLIMB_RAD * climb_sign)

	held_vis.position = recoil_pos
	held_vis.rotation = recoil_angle

	_weapon_tween = _character.create_tracked_tween()
	_weapon_tween.set_parallel(true)
	_weapon_tween.tween_property(held_vis, "position", _base_held_pos, RANGED_RECOVER_DURATION_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(held_vis, "rotation", 0.0, RANGED_RECOVER_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_weapon_tween.chain().tween_callback(func():
		if is_instance_valid(held_vis):
			held_vis.flip_v = false
	)

# =========================================================================
# 4. RZUT PRZEDMIOTEM (Zamach i Wyrzut)
# =========================================================================

## Odtwarza animację zamachu i wyrzutu przedmiotu miotanego (noża, granatu, bomby).
func play_throw_motion(target_world_pos: Vector2) -> void:
	if not _can_animate():
		return

	_cache_held_item_rest_pose()
	var throw_dir: Vector2 = _resolve_direction_to(target_world_pos)
	_orient_character_towards(throw_dir)

	var local_dir: Vector2 = throw_dir.rotated(-_character.global_rotation)
	_animate_body_motion(
		local_dir * THROW_BODY_LEAN_PX,
		UNARMED_STRETCH_SCALE,
		THROW_SNAP_DURATION_SEC,
		THROW_RECOVER_DURATION_SEC,
		Tween.TRANS_BACK
	)

	var held_vis: Sprite2D = _get_held_item_visual()
	if held_vis == null or not held_vis.visible:
		return

	_kill_tween(_weapon_tween)
	held_vis.rotation = -THROW_SPIN_ANGLE_RAD
	_weapon_tween = _character.create_tracked_tween()
	_weapon_tween.tween_property(held_vis, "rotation", THROW_SPIN_ANGLE_RAD, THROW_SNAP_DURATION_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_property(held_vis, "rotation", 0.0, THROW_RECOVER_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# =========================================================================
# 5. REAKCJA NA OTRZYMANE OBRAŻENIA (Hit Flinch & Red Flash)
# =========================================================================

## Odtwarza wizualną reakcję postaci na otrzymane obrażenia (odskok od napastnika, spłaszczenie i czerwony błysk).
func play_hit_reaction(hit_source_world_pos: Vector2 = Vector2.INF) -> void:
	if not _can_animate():
		return

	var flinch_dir: Vector2
	if hit_source_world_pos != Vector2.INF and hit_source_world_pos != Vector2.ZERO:
		flinch_dir = hit_source_world_pos.direction_to(_character.global_position)
	else:
		flinch_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	if flinch_dir == Vector2.ZERO:
		flinch_dir = Vector2.UP

	var local_flinch: Vector2 = flinch_dir.rotated(-_character.global_rotation) * HIT_FLINCH_DISTANCE_PX
	_animate_body_motion(
		local_flinch,
		HIT_SQUASH_SCALE,
		HIT_JOLT_IN_DURATION_SEC,
		HIT_JOLT_OUT_DURATION_SEC,
		Tween.TRANS_ELASTIC
	)
	_play_sprite_color_flash(HIT_FLASH_MODULATE, HIT_JOLT_IN_DURATION_SEC + HIT_JOLT_OUT_DURATION_SEC)

# =========================================================================
# 6. REAKCJA NA LECZENIE (Green Glow, Buoyant Lift & Rising Plus VFX)
# =========================================================================

## Odtwarza zielone podświetlenie postaci, lekkie uniesienie sprite'a oraz efekt unoszących się zielonych plusów.
## Parametr is_subtle = true redukuje intensywność dla cyklicznych tików regeneracji (RegenerationBuffEffect).
func play_heal_reaction(is_subtle: bool = false) -> void:
	if not _can_animate():
		return

	var flash_color: Color = HEAL_SUBTLE_FLASH_MODULATE if is_subtle else HEAL_FLASH_MODULATE
	var flash_duration: float = HEAL_SUBTLE_FLASH_DURATION_SEC if is_subtle else HEAL_FLASH_DURATION_SEC
	var lift_px: float = HEAL_SUBTLE_LIFT_DISTANCE_PX if is_subtle else HEAL_LIFT_DISTANCE_PX
	var stretch_ratio: Vector2 = HEAL_SUBTLE_STRETCH_SCALE if is_subtle else HEAL_STRETCH_SCALE

	var local_lift: Vector2 = Vector2(0.0, -lift_px).rotated(-_character.global_rotation)
	_animate_body_motion(
		local_lift,
		stretch_ratio,
		HEAL_LIFT_IN_DURATION_SEC,
		HEAL_LIFT_OUT_DURATION_SEC,
		Tween.TRANS_SINE
	)
	_play_sprite_color_flash(flash_color, flash_duration)
	_spawn_procedural_heal_vfx(is_subtle)

# =========================================================================
# METODY POMOCNICZE (DRY)
# =========================================================================

func _can_animate() -> bool:
	return (
		is_instance_valid(_character)
		and _character.is_inside_tree()
		and not _character.is_dead
		and not _character.is_respawning
		and not _character.is_frozen
	)

func _can_flash_sprite_color() -> bool:
	return (
		is_instance_valid(_character)
		and not _character.is_frozen
		and not _character.has_meta("original_self_modulate")
	)

func _resolve_direction_to(target_world_pos: Vector2) -> Vector2:
	if target_world_pos != Vector2.INF and target_world_pos != Vector2.ZERO:
		var dir: Vector2 = _character.global_position.direction_to(target_world_pos)
		if dir != Vector2.ZERO:
			return dir
	if _character.velocity.length_squared() > MIN_DIRECTION_VELOCITY_SQ:
		return _character.velocity.normalized()
	return Vector2.DOWN

func _orient_character_towards(world_dir: Vector2) -> void:
	if world_dir == Vector2.ZERO:
		return
	var ai_ctrl: Node = _character.get_node_or_null("AIController")
	if ai_ctrl != null and ai_ctrl.get("behavior_profile") != null:
		if bool(ai_ctrl.behavior_profile.can_rotate_to_target):
			return
	_character._update_sprite_direction(world_dir)

## Wspólna procedura animacji pozycji i skali sprite'a (DRY: ataki, odrzut, flinch oraz leczenie).
func _animate_body_motion(
	local_offset: Vector2,
	stretch_ratio: Vector2,
	in_duration: float,
	out_duration: float,
	out_position_trans: Tween.TransitionType
) -> void:
	var sprite: Node2D = _character.get_visual_sprite() as Node2D
	if sprite == null:
		return

	_kill_tween(_body_tween)
	var stretched_scale := Vector2(
		_base_sprite_scale.x * stretch_ratio.x,
		_base_sprite_scale.y * stretch_ratio.y
	)

	_body_tween = _character.create_tracked_tween()
	_body_tween.set_parallel(true)
	_body_tween.tween_property(sprite, "position", _base_sprite_pos + local_offset, in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(sprite, "scale", stretched_scale, in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.chain().set_parallel(true)
	_body_tween.tween_property(sprite, "position", _base_sprite_pos, out_duration).set_trans(out_position_trans).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(sprite, "scale", _base_sprite_scale, out_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Wspólna procedura krótkiego rozbłysku koloru sprite'a (DRY: czerwony dla obrażeń, zielony dla leczenia).
func _play_sprite_color_flash(flash_color: Color, duration: float) -> void:
	if not _can_flash_sprite_color():
		return
	var sprite: CanvasItem = _character.get_visual_sprite()
	if sprite == null:
		return

	_kill_tween(_color_flash_tween)
	sprite.self_modulate = flash_color
	_color_flash_tween = _character.create_tracked_tween()
	_color_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _get_character_scale_multiplier() -> float:
	if not is_instance_valid(_character):
		return 1.0
	return maxf(1.0, maxf(absf(_character.scale.x), absf(_character.scale.y)))

func _spawn_procedural_strike_arc(
	world_dir: Vector2,
	radius: float,
	color: Color,
	is_muzzle_flash: bool
) -> void:
	var vfx := _CombatStrikeVFX.new()
	var scale_mult: float = _get_character_scale_multiplier()
	var offset_dist: float = (MUZZLE_FLASH_OFFSET_PX if is_muzzle_flash else STRIKE_ARC_OFFSET_PX) * scale_mult
	vfx.setup(world_dir.angle(), radius * scale_mult, color, is_muzzle_flash, _swing_parity)
	_character.add_child(vfx)
	vfx.global_position = _character.global_position + (world_dir * offset_dist)

func _spawn_procedural_heal_vfx(is_subtle: bool) -> void:
	var vfx := _HealGlowVFX.new()
	var scale_mult: float = _get_character_scale_multiplier()
	var scaled_radius: float = maxf(
		HEAL_VFX_BASE_RADIUS_PX * scale_mult,
		_character.get_effective_combat_radius() * HEAL_VFX_COMBAT_RADIUS_RATIO
	)
	var duration: float = HEAL_VFX_SUBTLE_DURATION_SEC if is_subtle else HEAL_VFX_DURATION_SEC
	var particle_count: int = HEAL_VFX_SUBTLE_PARTICLE_COUNT if is_subtle else HEAL_VFX_FULL_PARTICLE_COUNT
	vfx.setup(_character, scaled_radius, duration, particle_count, is_subtle)
	_character.add_child(vfx)
	vfx.global_position = _character.global_position

func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

## Lekki, samooczyszczający się węzeł rysujący smugę cięcia/uderzenia lub błysk lufy (SRP).
class _CombatStrikeVFX extends Node2D:
	const MUZZLE_START_SCALE: float = 0.60
	const MUZZLE_END_SCALE: float = 1.35
	const MUZZLE_CORE_RATIO: float = 0.45
	const MUZZLE_MAIN_RAY_RATIO: float = 1.60
	const MUZZLE_SIDE_RAY_ANGLE_RAD: float = 0.45
	const MUZZLE_MAIN_RAY_WIDTH_PX: float = 3.0
	const MUZZLE_SIDE_RAY_WIDTH_PX: float = 2.0

	const ARC_SWEEP_HALF_RAD: float = 1.05
	const ARC_SWEEP_DRIFT_RAD: float = 0.35
	const ARC_START_WIDTH_PX: float = 5.0
	const ARC_END_WIDTH_PX: float = 1.5
	const ARC_START_RADIUS_MULT: float = 0.82
	const ARC_END_RADIUS_MULT: float = 1.12

	var _angle: float = 0.0
	var _radius: float = 24.0
	var _color: Color = Color.WHITE
	var _is_muzzle: bool = false
	var _parity: float = 1.0
	var _progress: float = 0.0

	func setup(angle: float, radius: float, color: Color, is_muzzle: bool, parity: float) -> void:
		_angle = angle
		_radius = radius
		_color = color
		_is_muzzle = is_muzzle
		_parity = parity
		top_level = true
		z_index = GameLayers.FX

	func _process(delta: float) -> void:
		_progress = minf(1.0, _progress + (delta / STRIKE_ARC_DURATION_SEC))
		queue_redraw()
		if _progress >= 1.0:
			queue_free()

	func _draw() -> void:
		var fade: float = 1.0 - _progress
		var draw_col: Color = _color
		draw_col.a *= fade

		if _is_muzzle:
			var cur_r: float = _radius * lerpf(MUZZLE_START_SCALE, MUZZLE_END_SCALE, _progress)
			var forward := Vector2.from_angle(_angle)
			draw_circle(Vector2.ZERO, cur_r * MUZZLE_CORE_RATIO, draw_col)
			draw_line(Vector2.ZERO, forward * (cur_r * MUZZLE_MAIN_RAY_RATIO), draw_col, MUZZLE_MAIN_RAY_WIDTH_PX, true)
			draw_line(Vector2.ZERO, forward.rotated(MUZZLE_SIDE_RAY_ANGLE_RAD) * cur_r, draw_col, MUZZLE_SIDE_RAY_WIDTH_PX, true)
			draw_line(Vector2.ZERO, forward.rotated(-MUZZLE_SIDE_RAY_ANGLE_RAD) * cur_r, draw_col, MUZZLE_SIDE_RAY_WIDTH_PX, true)
			return

		var center_ang: float = _angle + (lerpf(-ARC_SWEEP_DRIFT_RAD, ARC_SWEEP_DRIFT_RAD, _progress) * _parity)
		var width: float = lerpf(ARC_START_WIDTH_PX, ARC_END_WIDTH_PX, _progress)
		draw_arc(
			Vector2.ZERO,
			_radius * lerpf(ARC_START_RADIUS_MULT, ARC_END_RADIUS_MULT, _progress),
			center_ang - ARC_SWEEP_HALF_RAD,
			center_ang + ARC_SWEEP_HALF_RAD,
			STRIKE_ARC_POINTS,
			draw_col,
			width,
			true
		)

## Lekki, samooczyszczający się węzeł rysujący wyraźny zielony pierścień poświaty i unoszące się znaczki '+' (SRP).
class _HealGlowVFX extends Node2D:
	const RING_POINT_COUNT: int = 36
	const RING_START_SCALE: float = 0.78
	const RING_END_SCALE: float = 1.48
	const INNER_RING_SCALE_MULT: float = 0.78
	const RING_START_WIDTH_PX: float = 4.5
	const RING_END_WIDTH_PX: float = 1.5
	const INNER_RING_WIDTH_RATIO: float = 0.55
	const SUBTLE_ALPHA_MULTIPLIER: float = 0.78
	const PLUS_HALF_SIZE_PX: float = 6.0
	const PLUS_START_SCALE: float = 1.15
	const PLUS_END_SCALE: float = 0.75
	const PLUS_LINE_WIDTH_PX: float = 2.5
	const PLUS_OUTLINE_EXTRA_WIDTH_PX: float = 2.2
	const PLUS_RISE_DISTANCE_PX: float = 42.0
	const PLUS_HORIZONTAL_SPREAD_RATIO: float = 0.95
	const PLUS_HORIZONTAL_JITTER_RATIO: float = 0.18
	const PLUS_VERTICAL_START_RATIO: float = 0.45

	var _target: Node2D = null
	var _radius: float = 38.0
	var _duration: float = 0.55
	var _is_subtle: bool = false
	var _progress: float = 0.0
	var _particle_offsets: Array[Vector2] = []

	func setup(
		target: Node2D,
		radius: float,
		duration: float,
		particle_count: int,
		is_subtle: bool
	) -> void:
		_target = target
		_radius = radius
		_duration = maxf(0.05, duration)
		_is_subtle = is_subtle
		top_level = true
		z_index = GameLayers.FX

		_particle_offsets.clear()
		var spread_x: float = _radius * PLUS_HORIZONTAL_SPREAD_RATIO
		var spread_y: float = _radius * PLUS_VERTICAL_START_RATIO
		for i in range(particle_count):
			var ratio: float = (float(i) / float(maxi(1, particle_count - 1))) * 2.0 - 1.0
			var jitter_x: float = randf_range(-spread_x * PLUS_HORIZONTAL_JITTER_RATIO, spread_x * PLUS_HORIZONTAL_JITTER_RATIO)
			var start_y: float = randf_range(-spread_y, spread_y)
			_particle_offsets.append(Vector2((ratio * spread_x) + jitter_x, start_y))

	func _process(delta: float) -> void:
		if is_instance_valid(_target):
			global_position = _target.global_position
		_progress = minf(1.0, _progress + (delta / _duration))
		queue_redraw()
		if _progress >= 1.0:
			queue_free()

	func _draw() -> void:
		var fade: float = (1.0 - _progress) * (SUBTLE_ALPHA_MULTIPLIER if _is_subtle else 1.0)
		var cur_radius: float = _radius * lerpf(RING_START_SCALE, RING_END_SCALE, _progress)
		var ring_width: float = lerpf(RING_START_WIDTH_PX, RING_END_WIDTH_PX, _progress)

		# 1. Miękka zielona poświata wypełniająca obszar wokół postaci
		var halo_col: Color = HEAL_VFX_HALO_COLOR
		halo_col.a *= fade
		draw_circle(Vector2.ZERO, cur_radius, halo_col)

		# 2. Podwójny rozchodzący się pierścień aury leczenia
		var ring_col: Color = HEAL_VFX_RING_COLOR
		ring_col.a *= fade
		draw_arc(Vector2.ZERO, cur_radius, 0.0, TAU, RING_POINT_COUNT, ring_col, ring_width, true)

		var inner_ring_col: Color = ring_col
		inner_ring_col.a *= INNER_RING_WIDTH_RATIO
		draw_arc(
			Vector2.ZERO,
			cur_radius * INNER_RING_SCALE_MULT,
			0.0,
			TAU,
			RING_POINT_COUNT,
			inner_ring_col,
			ring_width * INNER_RING_WIDTH_RATIO,
			true
		)

		# 3. Unoszące się zielone znaczki '+' z kontrastowym ciemnozielonym obrysem
		var plus_col: Color = HEAL_VFX_PLUS_COLOR
		plus_col.a *= fade
		var outline_col: Color = HEAL_VFX_PLUS_OUTLINE_COLOR
		outline_col.a *= fade
		var rise_y: float = PLUS_RISE_DISTANCE_PX * _progress
		var arm: float = PLUS_HALF_SIZE_PX * lerpf(PLUS_START_SCALE, PLUS_END_SCALE, _progress)
		var outline_width: float = PLUS_LINE_WIDTH_PX + PLUS_OUTLINE_EXTRA_WIDTH_PX

		for base_offset in _particle_offsets:
			var center := Vector2(base_offset.x, base_offset.y - rise_y)
			draw_line(center + Vector2(-arm, 0.0), center + Vector2(arm, 0.0), outline_col, outline_width, true)
			draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, arm), outline_col, outline_width, true)
			draw_line(center + Vector2(-arm, 0.0), center + Vector2(arm, 0.0), plus_col, PLUS_LINE_WIDTH_PX, true)
			draw_line(center + Vector2(0.0, -arm), center + Vector2(0.0, arm), plus_col, PLUS_LINE_WIDTH_PX, true)
