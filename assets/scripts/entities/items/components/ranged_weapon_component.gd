class_name RangedWeaponComponent
extends ItemComponent

enum AmmoType { NONE, ARROW, BULLET, SHELL, ROCKET, ENERGY, GUN_BULLET, ASSAULT_RIFLE_BULLET, SHOTGUN_BULLET }

@export_category("Ustawienia Dystansowe")
@export var use_cooldown: float = 0.8 
@export var allow_auto_aim: bool = true

@export_group("Statystyki Własne Broni")
# --- CLEAN CODE: Zastępujemy luźną zmienną damage całym pakietem statystyk! ---
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

## Ustawiamy domyślny stan amunicji przy stworzeniu broni
func initialize_state(item_instance: ItemInstance) -> void:
	if uses_ammunition and not item_instance.state.has("ammo_count"):
		item_instance.state["ammo_count"] = 0
		item_instance.state["ammo_data"] = null
		item_instance.state["preferred_ammo_id"] = -1

func execute(actor: Node2D, target: Node2D, item_instance: ItemInstance) -> void:
	if projectile_scene == null: 
		return
		
	# --- INTELIGENTNE CELOWANIE ---
	var target_pos = Vector2.ZERO
	if target != null:
		target_pos = target.global_position
	elif actor.has_node("AimController") and actor.get_node("AimController").aim_scanner:
		var scanner = actor.get_node("AimController").aim_scanner
		target_pos = actor.global_position + scanner.target_position
	else:
		return 
		
	var stats = actor.get("interaction_and_attack_stats_script")
	var inv = actor.get("inventory") if actor.has_method("get_inventory") else null
	
	if stats == null or inv == null:
		return

	# 1. SYSTEM AMUNICJI
	var ammo_comp: AmmunitionComponent = null
	if uses_ammunition:
		var current_ammo = item_instance.state.get("ammo_count", 0)
		if current_ammo <= 0:
			if auto_reload and inv.has_method("reload_current_weapon"):
				if inv.reload_current_weapon():
					stats.trigger_reload_cooldown(reload_time)
			return
			
		# Strzał udany, pobieramy ItemData amunicji z pamięci...
		var stored_ammo_data = item_instance.state.get("ammo_data", null) as ItemData
		# ...i szukamy w nim komponentu balistycznego!
		if stored_ammo_data != null and stored_ammo_data.components != null:
			for comp in stored_ammo_data.components:
				if comp is AmmunitionComponent:
					ammo_comp = comp
					break
					
		item_instance.state["ammo_count"] = current_ammo - 1

	# 2. OBLICZANIE OBRAŻEŃ
	# Bierzemy bazową moc samej broni
	var total_base_damage = 0
	
	if attack_data != null:
		total_base_damage = attack_data.damage
	
	# Jeśli broń załadowała amunicję, dodajemy moc pocisku do mocy broni!
	if ammo_comp != null:
		total_base_damage += ammo_comp.damage
	
	var final_damage = int((total_base_damage + stats.damage_adder) * stats.damage_multiplier)
	if randf() <= stats.get_total_critical_rate():
		final_damage += int(stats.get_total_critical_damage())
		
	var generated_effects: Array[Effect] = []
	generated_effects.append(DamageEffect.new(final_damage))
	
	if stats.get_total_stun() > 0.0:
		generated_effects.append(StunEffect.new(stats.get_total_stun()))
	
	# Dodajemy unikalne efekty z samej broni (np. Laser nakładający Freeze)
	for eff in weapon_effects:
		if eff != null:
			generated_effects.append(eff.duplicate(true))

	# 3. FUZJA BALISTYCZNA Z NABOJEM
	var final_speed = projectile_speed
	var final_tex = projectile_texture
	
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
	proj.rotation = proj.direction.angle() + (PI / 2.0)
	
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

	# 5. ZUŻYCIE BRONI I ZEGAR
	item_instance.consume_durability(1)
	
	if inv != null:
		inv.clean_dead_items()
		inv.inventory_updated.emit()
		
	if uses_ammunition and auto_reload and item_instance.state.get("ammo_count", 0) <= 0:
		if inv.reload_current_weapon():
			stats.trigger_reload_cooldown(reload_time)
		return
		
	stats.reset_cooldown()
