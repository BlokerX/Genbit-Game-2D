class_name ThrowableExplosiveController
extends RefCounted
## Wspólny kontroler logiki zapalnika, wybuchu obszarowego (AoE), obsługi efektów (Trigger/Damage/Knockback)
## oraz weryfikacji sojuszników (FactionComponent) dla ThrowablePhysics (RigidBody2D) i ThrowableProjectile (Area2D).
## Realizuje zasady Single Responsibility (SRP) oraz Don't Repeat Yourself (DRY).

const SELF_HIT_GRACE_TIME_SEC: float = 0.1

var shooter_faction_name: StringName = &""
var time_alive: float = 0.0
var is_fuse_lit: bool = false
var fuse_timer: float = 0.0
var direct_hit_ref: Node2D = null

## Zapisuje nazwę frakcji strzelca w momencie utworzenia rzutki (chroni przed błędem, gdy strzelec zginie przed wybuchem).
func cache_shooter_faction(shooter: Node2D) -> void:
	if is_instance_valid(shooter):
		var my_faction: FactionComponent = shooter.get_node_or_null("FactionComponent") as FactionComponent
		if my_faction != null:
			shooter_faction_name = my_faction.faction_name

## Aktualizuje czas życia obiektu oraz odlicza opóźnienie zapalnika.
## Zwraca true, jeśli obiekt przekroczył swój czas życia i został zdetonowany.
func process_timers(
	host: Node2D,
	delta: float,
	lifetime: float,
	is_infinite: bool,
	activation_delay: float
) -> bool:
	time_alive += delta
	if not is_infinite and time_alive >= lifetime:
		if host.has_method("trigger_effect"):
			host.call("trigger_effect", null)
		return true

	if is_fuse_lit:
		fuse_timer += delta
		if fuse_timer >= activation_delay:
			is_fuse_lit = false
			if host.has_method("_execute_explosion"):
				host.call("_execute_explosion", direct_hit_ref)

	return false

## Obsługuje uzbrojenie zapalnika lub natychmiastową detonację obiektu.
func handle_trigger(
	host: Node2D,
	shooter: Node2D,
	direct_hit: Node2D,
	friendly_fire: bool,
	activation_delay: float,
	main_sprite: Sprite2D,
	activated_texture: Texture2D
) -> void:
	if not is_instance_valid(host):
		return

	# Ochrona przed natychmiastowym trafieniem samego strzelca w ułamku sekundy po rzucie
	if is_instance_valid(shooter) and direct_hit == shooter:
		if not friendly_fire or time_alive < SELF_HIT_GRACE_TIME_SEC:
			return

	if host.is_queued_for_deletion() or host.has_meta("is_triggered"):
		return
	host.set_meta("is_triggered", true)

	if main_sprite != null and activated_texture != null:
		main_sprite.texture = activated_texture

	if activation_delay > 0.0 and direct_hit == null:
		is_fuse_lit = true
		fuse_timer = 0.0
		direct_hit_ref = direct_hit
	else:
		if host.has_method("_execute_explosion"):
			host.call("_execute_explosion", direct_hit)

## Zbiera wszystkie cele w strefie rażenia (aoe_area lub fallback_area), filtruje sojuszników i nakłada efekty.
func execute_explosion(
	host: Node2D,
	shooter: Node2D,
	direct_hit: Node2D,
	aoe_area: Area2D,
	fallback_area: Area2D,
	friendly_fire: bool,
	effects_to_apply: Array[Effect],
	warn_on_missing_aoe: bool = false
) -> void:
	if not is_instance_valid(host):
		return

	var targets: Array[Node2D] = []
	var source_area: Area2D = aoe_area if aoe_area != null else fallback_area

	if source_area != null:
		targets.append_array(source_area.get_overlapping_bodies())
		for area in source_area.get_overlapping_areas():
			if not targets.has(area):
				targets.append(area)
	elif warn_on_missing_aoe:
		push_warning("BŁĄD: %s wybuchł, ale nie ma przypisanego 'aoe_area' w Inspektorze!" % host.name)

	if direct_hit != null and not targets.has(direct_hit):
		targets.append(direct_hit)

	for body in targets:
		if not is_instance_valid(body):
			continue
		if is_instance_valid(shooter) and body == shooter and not friendly_fire:
			continue
		if not friendly_fire and FactionComponent.is_ally_of(shooter, body, shooter_faction_name):
			continue

		if body.has_method("receive_effect"):
			for effect in effects_to_apply:
				if effect != null:
					var cloned_eff: Effect = effect.duplicate(true)
					cloned_eff.source_position = host.global_position
					cloned_eff.source_entity = shooter if is_instance_valid(shooter) else null
					body.receive_effect(cloned_eff)

	host.queue_free()

## Wspólna obsługa odbierania efektów zewnętrznych (detonacja łańcuchowa od wybuchu, obrażeń lub odrzut).
func handle_received_effect(
	host: Node2D,
	effect: Effect,
	activate_on_trigger: bool,
	activate_on_damage: bool,
	can_be_knocked_back: bool
) -> bool:
	if not is_instance_valid(host) or effect == null:
		return false

	if effect is TriggerEffect:
		if activate_on_trigger and not host.is_queued_for_deletion():
			host.call("trigger_effect", null)
		return true

	if effect is DamageEffect:
		if activate_on_damage and not host.is_queued_for_deletion():
			host.call("trigger_effect", null)
		return true

	if effect is KnockbackEffect:
		if not can_be_knocked_back:
			return true
		return effect.apply_effect(host)

	return effect.apply_effect(host)
