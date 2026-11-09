class_name RangedWeaponComponent
extends ItemComponent
## Komponent broni dystansowej (strzeleckiej / energetycznej).

const FeedbackDispatcherType = preload("res://assets/scripts/audio_system/feedback_dispatcher.gd")
const PROJECTILE_VERTICAL_SPRITE_OFFSET_RAD: float = PI / 2.0
const PERCENT_MULTIPLIER: float = 100.0
const DURABILITY_CONSUMPTION_PER_SHOT: int = 1
const NO_PREFERRED_AMMO_ID: int = -1

# Stałe oceny zagrożenia dla AI (Brak magicznych liczb)
const AI_RANGED_BASE_THREAT_BONUS: float = 20.0
const AI_THREAT_DAMAGE_WEIGHT: float = 0.85
const AI_THREAT_EFFECT_BONUS: float = 8.0

@export_group("Oprawa użycia")
## Oprawa wizualna i dźwiękowa tego konkretnego strzału.
@export var use_feedback: FeedbackCue

enum AmmoType { NONE, ARROW, BULLET, SHELL, ROCKET, ENERGY, GUN_BULLET, ASSAULT_RIFLE_BULLET, SHOTGUN_BULLET }

@export_category("Ustawienia Dystansowe")
@export var use_cooldown: float = 0.8 
@export var allow_auto_aim: bool = true

@export_group("Statystyki Własne Broni")
@export var attack_data: AttackData
## Efekty nakładane przez samą broń (np. Zamrożenie z lasera).
@export var weapon_effects: Array[Effect] = []

@export_group("Amunicja")
@export var uses_ammunition: bool = true
@export var accepted_ammunition_type: AmmoType = AmmoType.NONE
@export var magazine_capacity: int = 1
@export var auto_reload: bool = true
@export var reload_time: float = 2.5

@export_group("Pocisk")
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 500.0
@export var projectile_lifetime: float = 2.0
@export var projectile_scene: PackedScene

## Ustawiamy domyślny stan amunicji przy stworzeniu broni.
func initialize_state(item_instance: ItemInstance) -> void:
	if uses_ammunition and not item_instance.state.has("ammo_count"):
		item_instance.state["ammo_count"] = 0
		item_instance.state["ammo_data"] = null
		item_instance.state["preferred_ammo_id"] = NO_PREFERRED_AMMO_ID

func execute(actor: Node2D, target: Node2D, item_instance: ItemInstance) -> void:
	if projectile_scene == null: 
		return

	# --- INTELIGENTNE CELOWANIE ---
	var target_pos: Vector2 = Vector2.ZERO
	if target != null:
		target_pos = target.global_position
	elif actor.has_node("AimController") and actor.get_node("AimController").aim_scanner:
		var scanner = actor.get_node("AimController").aim_scanner
		target_pos = actor.global_position + scanner.target_position
	else:
		return 

	var stats = actor.get("interaction_and_attack_stats_script")
	var inv = actor.call("get_inventory") if actor.has_method("get_inventory") else null
	if stats == null:
		return

	# 1. SYSTEM AMUNICJI
	var ammo_comp: AmmunitionComponent = null

	if uses_ammunition:
		var current_ammo: int = item_instance.state.get("ammo_count", 0)

		if current_ammo <= 0:
			if auto_reload and inv != null and inv.has_method("reload_current_weapon"):
				var reloaded: bool = inv.reload_current_weapon()
				if reloaded:
					stats.trigger_reload_cooldown(reload_time)
				if actor.has_method("play_reload_feedback"):
					actor.call("play_reload_feedback", reloaded)
			return

		var stored_ammo_id: StringName = item_instance.state.get("ammo_id", &"")
		var stored_ammo_data: ItemData = ItemDatabase.get_item(stored_ammo_id)

		if stored_ammo_data != null and stored_ammo_data.components != null:
			for comp in stored_ammo_data.components:
				if comp is AmmunitionComponent:
					ammo_comp = comp
					break

		item_instance.state["ammo_count"] = current_ammo - 1

	# 2. OBLICZANIE OBRAŻEŃ
	var total_base_damage: int = 0
	var base_penetration: float = 0.0
	if attack_data != null:
		total_base_damage = attack_data.damage
		base_penetration = attack_data.armor_penetration

	if ammo_comp != null:
		total_base_damage += ammo_comp.damage

	var final_damage: int = int((total_base_damage + stats.damage_adder) * stats.damage_multiplier)
	if randf() <= stats.get_total_critical_rate():
		final_damage += int(stats.get_total_critical_damage())

	var final_penetration: float = clampf(base_penetration + stats.armor_penetration_adder, 0.0, 1.0)

	var generated_effects: Array[Effect] = []
	generated_effects.append(DamageEffect.new(final_damage, final_penetration))

	if stats.get_total_stun() > 0.0:
		generated_effects.append(StunEffect.new(stats.get_total_stun()))

	for eff in weapon_effects:
		if eff != null:
			generated_effects.append(eff.duplicate(true))

	# 3. FUZJA BALISTYCZNA Z NABOJEM
	var final_speed: float = projectile_speed
	var final_tex: Texture2D = projectile_texture

	if ammo_comp != null:
		final_speed *= ammo_comp.speed_multiplier
		if ammo_comp.override_projectile_texture != null:
			final_tex = ammo_comp.override_projectile_texture
		if ammo_comp.effects != null:
			for eff in ammo_comp.effects:
				if eff != null:
					generated_effects.append(eff.duplicate(true))

	# 4. SPAWN POCISKU
	var proj = projectile_scene.instantiate()
	proj.shooter = actor
	proj.global_position = actor.global_position
	proj.direction = actor.global_position.direction_to(target_pos)
	proj.rotation = proj.direction.angle() + PROJECTILE_VERTICAL_SPRITE_OFFSET_RAD

	if "effects_to_apply" in proj:
		proj.effects_to_apply = generated_effects
	if "speed" in proj:
		proj.speed = final_speed
	if "lifetime" in proj:
		proj.lifetime = projectile_lifetime

	var sprite = proj.get_node_or_null("Sprite2D")
	if sprite != null and final_tex != null:
		sprite.texture = final_tex

	if actor.has_signal("entity_spawn_requested"):
		actor.emit_signal("entity_spawn_requested", proj, actor.global_position)
	FeedbackDispatcherType.play_for_actor(use_feedback, actor, target)

	# 5. ZUŻYCIE BRONI I ZEGAR
	item_instance.consume_durability(DURABILITY_CONSUMPTION_PER_SHOT)
	if inv != null:
		inv.clean_dead_items()
		inv.inventory_updated.emit()

	if uses_ammunition and auto_reload and item_instance.state.get("ammo_count", 0) <= 0:
		if inv != null and inv.has_method("reload_current_weapon"):
			if inv.reload_current_weapon():
				stats.trigger_reload_cooldown(reload_time)
				if actor.has_method("play_reload_feedback"):
					actor.call("play_reload_feedback", true)
				return

	stats.reset_cooldown()

# --- IMPLEMENTACJA KONTRAKTU BOJOWEGO (SOLID - OCP) ---

func is_weapon_component() -> bool:
	return true

func requires_melee_range_check() -> bool:
	return false

func get_use_feedback() -> FeedbackCue:
	return use_feedback

func apply_held_stats_to(attack_stats: Node) -> bool:
	if attack_stats == null:
		return false
	if attack_stats.has_method("change_item_cooldown"):
		attack_stats.call("change_item_cooldown", use_cooldown)
	if "actual_attack_data" in attack_stats:
		attack_stats.set("actual_attack_data", attack_data)
	if "actual_extra_effects" in attack_stats:
		attack_stats.set("actual_extra_effects", weapon_effects)
	return true

func get_ai_threat_score() -> float:
	var dmg: float = float(attack_data.damage) if attack_data != null else 0.0
	var effects_bonus: float = float(weapon_effects.size()) * AI_THREAT_EFFECT_BONUS if weapon_effects != null else 0.0
	return AI_RANGED_BASE_THREAT_BONUS + (dmg * AI_THREAT_DAMAGE_WEIGHT) + effects_bonus

# --- OPISY UI (OCP) ---

func get_tooltip_info(item_instance: ItemInstance) -> String:
	var text: String = ""
	if attack_data != null:
		text += "Obrażenia Bazowe: " + str(attack_data.damage) + "\n"
		text += "Zasięg Celowania: " + str(attack_data.max_range) + "\n"
		if attack_data.critical_rate > 0.0:
			text += "Szansa na Kryta: " + str(attack_data.critical_rate * PERCENT_MULTIPLIER) + "%\n"

	if weapon_effects.size() > 0:
		text += "Efekty Broni: " + str(weapon_effects.size()) + "\n"
		for effect in weapon_effects:
			if effect != null:
				text += "- " + effect.effect_name + "\n"

	if uses_ammunition:
		var cur_ammo: int = item_instance.state.get("ammo_count", 0) if item_instance != null else 0
		text += "Typ Amunicji: " + str(AmmoType.keys()[accepted_ammunition_type]) + "\n"
		text += "Magazynek: " + str(cur_ammo) + " / " + str(magazine_capacity) + "\n"
	else:
		text += "Zasilanie: Nieskończone (Brak amunicji)\n"
	return text

func get_hud_info(item_instance: ItemInstance, is_advanced: bool) -> String:
	var text: String = ""
	if attack_data != null:
		if is_advanced:
			text += "Obrażenia (Baza): " + str(attack_data.damage) + "\n"
			text += "Zasięg Celowania: " + str(attack_data.max_range) + "\n"
			text += "Szybkość (Cooldown): " + str(use_cooldown) + "s\n"
			text += "Przeładowanie: " + str(reload_time) + "s\n"
			text += "Szybkość Pocisku: " + str(projectile_speed) + "\n"
			if attack_data.critical_rate > 0.0:
				text += "Szansa na Kryta: " + str(attack_data.critical_rate * PERCENT_MULTIPLIER) + "%\n"
		else:
			if attack_data.damage > 0:
				text += "Obrażenia (Baza): " + str(attack_data.damage) + "\n"
			text += "Zasięg Strzału: " + str(attack_data.max_range) + "\n"

	if weapon_effects.size() > 0:
		if is_advanced:
			text += "Efekty Nakładane (" + str(weapon_effects.size()) + "):\n"
			for effect in weapon_effects:
				if effect != null:
					var dur_str: String = " (" + str(effect.get("duration")) + "s)" if "duration" in effect else ""
					text += "  - " + effect.effect_name + dur_str + "\n"
		else:
			text += "Statusy Specjalne: Tak\n"

	if uses_ammunition:
		var cur_ammo: int = item_instance.state.get("ammo_count", 0) if item_instance != null else 0
		text += "Amunicja: " + str(AmmoType.keys()[accepted_ammunition_type]) + "\n"
		text += "Magazynek: " + str(cur_ammo) + " / " + str(magazine_capacity) + "\n"
	else:
		text += "Zasilanie: Nieskończone\n"
	return text
