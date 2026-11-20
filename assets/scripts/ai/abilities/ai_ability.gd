extends Resource
class_name AIAbility
## Bazowa klasa dla wszystkich zdolności specjalnych AI (SOLID - OCP / DRY).
## Integruje ataki specjalne z systemem walki (AttackData, InteractionAndAttackStatsComponent,
## Stun, Kryt, Penetracja, Odrzut) oraz pozwala komponować dowolne skutki trafienia w plikach .tres.

const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")

# --- STAŁE DOMENOWE (Brak magicznych liczb) ---
## Domyślny promień kolizji bojowej dla atakującego, jeśli nie zdefiniowano combat_radius.
const DEFAULT_ENTITY_COMBAT_RADIUS: float = 40.0
## Domyślny promień kolizji bojowej dla celu, jeśli nie zdefiniowano combat_radius.
const DEFAULT_TARGET_COMBAT_RADIUS: float = 20.0
## Minimalny kwadrat przesunięcia po ześlizgu na ścianie, poniżej którego ruch jest ignorowany.
const MIN_SLIDE_REMAINDER_SQ: float = 0.01
## Minimalny czas trwania Tweena zabezpieczający przed dzieleniem przez zero.
const MIN_TWEEN_DURATION_SEC: float = 0.01
## Minimalny efektywny cooldown zdolności po zastosowaniu modyfikatorów (w sekundach).
const MIN_EFFECTIVE_COOLDOWN_SEC: float = 0.25
## Minimalny kwadrat kroku ruchu kinematycznego w create_kinematic_dash_tween.
const MIN_KINEMATIC_STEP_SQ: float = 0.0001
## Domyślny czas trwania odrzutu generowanego z AttackData.knockback_force (w sekundach).
const DEFAULT_ATTACK_KNOCKBACK_DURATION_SEC: float = 0.35

@export_group("Podstawowe Parametry")
## Nazwa wyświetlana i diagnostyczna zdolności specjalnej.
@export var ability_name: String = "Special Ability"
## Bazowy czas odnowienia zdolności (w sekundach).
@export var cooldown: float = 5.0
## Minimalny dystans (od krawędzi do krawędzi), z którego AI może uruchomić zdolność.
@export var min_range: float = 0.0
## Maksymalny dystans (od krawędzi do krawędzi), z którego AI może uruchomić zdolność.
@export var max_range: float = 200.0
## Oprawa dźwiękowa i wizualna odtwarzana przy rozpoczęciu wykonywania zdolności.
@export var feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemies/enemy_super_attack.tres"
)

@export_category("Inteligencja i Wyjątki")
## O ile sekund AI musi być w aktywnej walce, zanim rzuci ten czar po raz pierwszy?
## Zapobiega to używaniu potężnych ataków w ułamku sekundy po zauważeniu gracza.
@export var first_cast_delay: float = 5.0

## Szansa na rzucenie czaru, gdy jest gotowy (np. 0.6 = 60%).
## Jeśli AI oblało rzut, odczeka ułamek sekundy przed kolejną próbą (wahanie).
@export_range(0.0, 1.0) var cast_chance: float = 0.7

## Jeśli włączone, AI może rzucić umiejętność NAWET jeśli inna jest aktualnie wykonywana.
@export var ignore_global_cast_lock: bool = false

@export_category("System Walki i Uniwersalne Skutki (.tres - OCP)")
@export_group("Statystyki Ataku (AttackData i Skalowanie)")
## Opcjonalny zasób AttackData definiujący bazowe obrażenia, kryt, penetrację pancerza, stun i odrzut zdolności.
## Gdy pusty (null), zdolność korzysta ze swoich domyślnych pól obrażeń (pełna kompatybilność ze starszymi .tres).
@export var attack_data: AttackData = null
## Kategoria żywiołu/domeny dla obrażeń zadawanych przez zdolność.
## Ustaw NONE, aby użyć domyślnej kategorii konkretnego skryptu (np. FIRE_BURN dla lasera, POISON_ACID dla kwasu).
@export var damage_category: Effect.EffectCategory = Effect.EffectCategory.NONE
## Jeśli włączone (true), obrażenia, kryt, penetracja pancerza, stun i odrzut zdolności skalują się
## z aktualnymi buffami/debuffami postaci (InteractionAndAttackStatsComponent).
@export var scale_with_attacker_stats: bool = true
## Jeśli włączone (true), czas odnowienia zdolności (cooldown) skaluje się z cooldown_multiplier postaci.
@export var scale_cooldown_with_attacker_stats: bool = false
## Jeśli włączone (true), zdolność generuje StunEffect na podstawie attack_data.stun_time (oraz bonusów stuna postaci).
@export var apply_attack_stun: bool = true
## Jeśli włączone (true) i attack_data == null, a zdolność nie ma własnego stuna, dziedziczy bazowy hand_attack_data.stun_time.
@export var inherit_hand_stun_without_attack_data: bool = false
## Czas trwania odrzutu (w sekundach), gdy odrzut jest wyznaczany z attack_data.knockback_force.
@export_range(0.05, 3.0, 0.05) var attack_knockback_duration: float = DEFAULT_ATTACK_KNOCKBACK_DURATION_SEC

@export_group("Dodatkowe Efekty Zdolności (Konfiguracja w .tres)")
## Otwarta lista dowolnych efektów (np. FreezeEffect, SlowEffect, PoisonDebuffEffect, ArmorDebuffEffect),
## które zostaną automatycznie nałożone na każdy trafiony cel bez konieczności modyfikowania kodu (SOLID - OCP).
@export var on_hit_effects: Array[Effect] = []
## Opcjonalna lista efektów nakładanych na samego rzucającego w chwili uruchomienia zdolności (np. tarcza, speed, regeneracja).
@export var caster_self_effects: Array[Effect] = []

## Zwraca true, jeśli zdolność jest gotowa do użycia (sprawdza dystans i warunki specjalne).
func check_conditions(_attacker: CharacterEntity, _target: CharacterEntity, distance: float) -> bool:
	if distance < min_range or distance > max_range:
		return false
	return true

## Główna logika umiejętności, nadpisywana w konkretnych plikach.
func execute(_attacker: CharacterEntity, _target: CharacterEntity) -> void:
	pass

# =========================================================================
# INTEGRACJA Z SYSTEMEM WALKI (SOLID - OCP / DRY)
# =========================================================================

## Oblicza efektywny cooldown zdolności z uwzględnieniem opcjonalnego skalowania statystykami rzucającego.
func get_effective_cooldown(attacker: CharacterEntity) -> float:
	if not scale_cooldown_with_attacker_stats or not is_instance_valid(attacker):
		return maxf(MIN_EFFECTIVE_COOLDOWN_SEC, cooldown)
	var stats: InteractionAndAttackStatsComponent = attacker.interaction_and_attack_stats_script
	if stats == null:
		return maxf(MIN_EFFECTIVE_COOLDOWN_SEC, cooldown)
	var scaled_cd: float = (cooldown + stats.cooldown_adder) * stats.cooldown_multiplier
	return maxf(MIN_EFFECTIVE_COOLDOWN_SEC, scaled_cd)

## Nakłada skonfigurowane w .tres efekty własne (caster_self_effects) na rzucającego w chwili użycia zdolności.
func apply_caster_self_effects(attacker: CharacterEntity) -> void:
	if caster_self_effects.is_empty() or not is_instance_valid(attacker):
		return
	apply_effects_to_target(attacker, attacker, caster_self_effects, attacker.global_position)

## Buduje kompletną, gotową do nałożenia listę efektów trafienia (Damage + Kryt + Penetracja + Stun + Knockback
## + efekty specyficzne skryptu + otwarta lista on_hit_effects z pliku .tres).
## Realizuje zasady DRY oraz Open/Closed: wszystkie zdolności korzystają z jednej spójnej formuły walki.
func build_hit_effects(
	attacker: CharacterEntity,
	fallback_damage: int = 0,
	fallback_category: Effect.EffectCategory = Effect.EffectCategory.PHYSICAL_DAMAGE,
	specific_effects: Array[Effect] = [],
	fallback_stun_time: float = 0.0,
	fallback_knockback_force: float = 0.0,
	fallback_knockback_duration: float = -1.0
) -> Array[Effect]:
	var stats: InteractionAndAttackStatsComponent = (
		attacker.interaction_and_attack_stats_script
		if is_instance_valid(attacker)
		else null
	)

	var base_damage: int = attack_data.damage if attack_data != null else fallback_damage
	var base_crit_rate: float = attack_data.critical_rate if attack_data != null else 0.0
	var base_crit_dmg: int = attack_data.critical_damage if attack_data != null else 0
	var base_penetration: float = attack_data.armor_penetration if attack_data != null else 0.0
	var base_stun: float = attack_data.stun_time if attack_data != null else fallback_stun_time
	var base_knockback: float = attack_data.knockback_force if attack_data != null else fallback_knockback_force

	if (
		attack_data == null
		and inherit_hand_stun_without_attack_data
		and base_stun <= 0.0
		and stats != null
		and stats.hand_attack_data != null
	):
		base_stun = stats.hand_attack_data.stun_time

	var final_damage: int = base_damage
	var final_crit_rate: float = base_crit_rate
	var final_crit_dmg: int = base_crit_dmg
	var final_penetration: float = clampf(base_penetration, 0.0, InteractionAndAttackStatsComponent.MAX_ARMOR_PENETRATION)
	var final_stun: float = base_stun if apply_attack_stun else 0.0
	var final_knockback: float = base_knockback

	if scale_with_attacker_stats and stats != null:
		if base_damage > 0:
			final_damage = maxi(1, int(round((float(base_damage) + stats.damage_adder) * stats.damage_multiplier)))
		final_crit_rate = clampf((base_crit_rate + stats.critical_rate_adder) * stats.critical_rate_multiplier, 0.0, 1.0)
		final_crit_dmg = maxi(0, int(round((float(base_crit_dmg) + stats.critical_damage_adder) * stats.critical_damage_multiplier)))
		final_penetration = clampf(
			base_penetration + stats.armor_penetration_adder,
			0.0,
			InteractionAndAttackStatsComponent.MAX_ARMOR_PENETRATION
		)
		if apply_attack_stun and (base_stun > 0.0 or stats.stun_adder > 0.0):
			final_stun = maxf(0.0, (base_stun + stats.stun_adder) * stats.stun_multiplier)
		if base_knockback > 0.0 or stats.knockback_adder > 0.0:
			final_knockback = maxf(0.0, (base_knockback + stats.knockback_adder) * stats.knockback_multiplier)

	if final_damage > 0 and final_crit_rate > 0.0 and randf() <= final_crit_rate:
		final_damage += final_crit_dmg

	var result: Array[Effect] = []

	if final_damage > 0:
		var dmg_eff := DamageEffect.new(final_damage, final_penetration)
		dmg_eff.effect_category = resolve_damage_category(fallback_category)
		result.append(dmg_eff)

	if final_stun > 0.0 and not _contains_stun_effect(specific_effects):
		result.append(StunEffect.new(final_stun))

	if final_knockback > 0.0 and not _contains_knockback_effect(specific_effects):
		var kb_dur: float = (
			fallback_knockback_duration
			if fallback_knockback_duration > 0.0
			else attack_knockback_duration
		)
		result.append(KnockbackEffect.new(final_knockback, kb_dur))

	for spec_eff in specific_effects:
		if spec_eff != null:
			result.append(spec_eff.duplicate(true) as Effect)

	for extra_eff in on_hit_effects:
		if extra_eff != null:
			result.append(extra_eff.duplicate(true) as Effect)

	return result

## Zwraca kategorię obrażeń zdolności (priorytet ma jawnie wybrana damage_category w .tres).
func resolve_damage_category(fallback_category: Effect.EffectCategory) -> Effect.EffectCategory:
	if damage_category != Effect.EffectCategory.NONE:
		return damage_category
	return fallback_category

## Uniwersalna metoda aplikująca klonowane efekty na cel z pełnym wstrzyknięciem source_entity i source_position (DRY).
static func apply_effects_to_target(
	attacker: Variant,
	target: Node2D,
	effects: Array[Effect],
	origin_pos: Vector2
) -> bool:
	if not is_instance_valid(target) or effects.is_empty():
		return false

	var valid_attacker: Node2D = attacker as Node2D if is_instance_valid(attacker) and attacker is Node2D else null
	var applied_any: bool = false

	for eff in effects:
		if eff == null:
			continue
		var cloned_eff: Effect = eff.duplicate(true) as Effect
		cloned_eff.source_entity = valid_attacker
		cloned_eff.source_position = origin_pos
		if target.has_method("receive_effect"):
			if bool(target.call("receive_effect", cloned_eff)):
				applied_any = true
		elif cloned_eff.apply_effect(target):
			applied_any = true

	return applied_any

func _contains_stun_effect(effects: Array[Effect]) -> bool:
	for eff in effects:
		if eff is StunEffect:
			return true
	return false

func _contains_knockback_effect(effects: Array[Effect]) -> bool:
	for eff in effects:
		if eff is KnockbackEffect:
			return true
	return false

# =========================================================================
# WSPÓLNE METODY POMOCNICZE DLA ZDOLNOŚCI AI (Zasady DRY i SOLID)
# =========================================================================

## Pobiera AICombatController i ustawia flagę rzucania umiejętności (is_casting_ability).
static func set_casting_state(attacker: CharacterEntity, is_casting: bool) -> AICombatController:
	if not is_instance_valid(attacker):
		return null
	var ai_controller: Node = attacker.get_node_or_null("AIController")
	var combat_ctrl: AICombatController = (
		ai_controller.get_node_or_null("AICombatController") as AICombatController
		if ai_controller != null
		else null
	)
	if combat_ctrl != null:
		combat_ctrl.is_casting_ability = is_casting
	return combat_ctrl

## Sprawdza w profilu zachowania AI, czy postać obraca się płynnie (rotacyjnie), czy klatkowo (8 kierunków).
static func can_entity_rotate(attacker: CharacterEntity) -> bool:
	if not is_instance_valid(attacker):
		return false
	var ai_controller: Node = attacker.get_node_or_null("AIController")
	if ai_controller != null and ai_controller.get("behavior_profile") != null:
		return bool(ai_controller.behavior_profile.can_rotate_to_target)
	return false

## Obraca postać w podanym kierunku zgodnie z jej profilem zachowania (płynny obrót lub 8-kierunkowy sprite).
static func orient_towards(attacker: CharacterEntity, direction: Vector2, lerp_weight: float = 1.0) -> void:
	if not is_instance_valid(attacker) or direction == Vector2.ZERO:
		return
	if can_entity_rotate(attacker):
		var target_angle: float = direction.angle()
		if lerp_weight >= 1.0:
			attacker.rotation = target_angle
		else:
			attacker.rotation = lerp_angle(attacker.rotation, target_angle, lerp_weight)
	elif attacker.has_method("_update_sprite_direction"):
		attacker._update_sprite_direction(direction)

## Bezpiecznie spawnuje węzeł pomocniczy umiejętności (plamę, laser, falę) w strukturze Mapy.
static func spawn_ability_node(attacker: Node2D, node_to_spawn: Node2D, spawn_pos: Vector2) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(node_to_spawn):
		return
	node_to_spawn.global_position = spawn_pos
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", node_to_spawn, spawn_pos)
		return
	var parent_node: Node = attacker.get_parent()
	if parent_node != null:
		parent_node.add_child(node_to_spawn)
		node_to_spawn.global_position = spawn_pos
	elif attacker.is_inside_tree() and attacker.get_tree().current_scene != null:
		attacker.get_tree().current_scene.add_child(node_to_spawn)
		node_to_spawn.global_position = spawn_pos

## Oblicza dystans od krawędzi do krawędzi (Edge-to-Edge) pomiędzy dwoma obiektami (DRY - z uwzględnieniem skali bossów).
static func get_edge_distance(entity_a: Variant, entity_b: Variant) -> float:
	return CharacterEntity.get_edge_distance_between(entity_a, entity_b)

## Deleguje sprawdzenie sojuszu do FactionComponent (parametry Variant chronią przed błędem 'previously freed').
static func is_ally_of(attacker: Variant, target: Variant, fallback_faction_name: StringName = &"") -> bool:
	return FactionComponent.is_ally_of(attacker, target, fallback_faction_name)

## Wywołuje wstrząs kamery gracza (naprawia błąd szukania CameraComponent bezpośrednio w current_scene).
static func trigger_camera_shake(context_node: Node, trauma_amount: float) -> void:
	if trauma_amount <= 0.0 or not is_instance_valid(context_node) or not context_node.is_inside_tree():
		return
	var tree: SceneTree = context_node.get_tree()
	if tree == null:
		return

	# 1. Sprawdzamy aktywną kamerę 2D w Viewporcie
	var viewport: Viewport = context_node.get_viewport()
	if viewport != null:
		var active_cam: Camera2D = viewport.get_camera_2d()
		if is_instance_valid(active_cam) and active_cam.has_method("add_trauma"):
			active_cam.call("add_trauma", trauma_amount)
			return

	# 2. Fallback: Szukamy CameraComponent u gracza
	var player: Node = tree.get_first_node_in_group("Player")
	if is_instance_valid(player):
		var player_cam: Node = player.get_node_or_null("CameraComponent")
		if is_instance_valid(player_cam) and player_cam.has_method("add_trauma"):
			player_cam.call("add_trauma", trauma_amount)

## Tworzy bezpiecznego fizycznie Tweena szarży/skoku (move_and_collide zamiast nadpisywania global_position).
## Gwarantuje, że skaczący boss NIGDY nie wepchnie gracza w ścianę ani sam nie wypadnie poza mapę!
static func create_kinematic_dash_tween(
	attacker: CharacterEntity,
	target_world_pos: Vector2,
	duration: float,
	trans_type: Tween.TransitionType = Tween.TRANS_QUAD,
	ease_type: Tween.EaseType = Tween.EASE_OUT
) -> Tween:
	var tween: Tween = attacker.create_tracked_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(trans_type).set_ease(ease_type)

	var last_virtual_pos: Array[Vector2] = [attacker.global_position]
	var start_pos: Vector2 = attacker.global_position

	tween.tween_method(
		func(interpolated_pos: Vector2):
			if not is_instance_valid(attacker) or not attacker.is_inside_tree():
				return
			var step_motion: Vector2 = interpolated_pos - last_virtual_pos[0]
			last_virtual_pos[0] = interpolated_pos
			if step_motion.length_squared() <= MIN_KINEMATIC_STEP_SQ:
				return
			var collision: KinematicCollision2D = attacker.move_and_collide(step_motion)
			if collision != null:
				var slide_vec: Vector2 = collision.get_remainder().slide(collision.get_normal())
				if slide_vec.length_squared() > MIN_SLIDE_REMAINDER_SQ:
					attacker.move_and_collide(slide_vec),
		start_pos,
		target_world_pos,
		maxf(MIN_TWEEN_DURATION_SEC, duration)
	)
	return tween
