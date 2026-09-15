extends AIAbility
class_name BionicTailAbility

@export_category("Zdolność: Wirujący Ogon")

@export_group("Czasy Trwania (Spowolnione dla czytelności)")
## Czas, w którym mutant odwraca się plecami do ofiary, sygnalizując przygotowanie do ataku.
@export_range(0.1, 2.0, 0.1) var telegraph_time: float = 1.0

## Czas trwania samego doskoku (lotu) w kierunku gracza. Im mniej, tym szybszy i bardziej gwałtowny skok.
@export_range(0.1, 2.0, 0.1) var dash_forward_time: float = 0.5

## Czas trwania obrotu (bączka) i wizualizacji cięcia. Dłuższy czas ułatwia zobaczenie pełnego obrotu klatkowego.
@export_range(0.1, 3.0, 0.1) var slash_duration: float = 1.5

## Czas powrotu mutanta na pozycję startową (brane pod uwagę tylko, jeśli włączono 'return_to_original_position').
@export_range(0.1, 2.0, 0.1) var dash_return_time: float = 0.4


@export_group("Doskok i Hitbox Ataku")
## Odległość (w pikselach), na jaką mutant doskakuje w stronę gracza przed rozpoczęciem kręcenia ogonem.
@export_range(10.0, 300.0, 10.0) var dash_distance: float = 60.0

## Czy po ataku mutant ma wycofać się i natychmiast wrócić na pozycję, z której zaczął szarżę?
@export var return_to_original_position: bool = false

## Zasięg (promień) wizualizacji cięcia. Wyznacza też fizyczny obszar (AoE), w którym zadawane są obrażenia.
@export_range(20.0, 300.0, 10.0) var slash_radius: float = 120.0

## Ile pełnych obrotów ma wykonać postać (1.0 = 360 stopni). Wartość 1.5 (540 stopni) gwarantuje powrót twarzą do gracza.
@export_range(0.5, 3.5, 0.5) var spin_rotations: float = 1.5 

## Czy ogon ma ranić i odrzucać również innych przeciwników/sojuszników stojących w zasięgu cięcia?
@export var friendly_fire: bool = false


@export_group("Wizualizacje i Warstwy")
## Z-Index (warstwa rysowania) dla efektu cięcia. Domyślnie 10 (nad podłogą, równo z postaciami).
@export var slash_z_index: int = GameLayers.ENTITIES
## Kolor wizualnego śladu zostawianego przez ogon podczas obrotu w powietrzu.
@export var slash_color: Color = Color(0.2, 0.902, 0.302, 0.573)
## Kolor wewnętrznego, jasnego rdzenia cięcia.
@export var slash_core_color: Color = Color(1.0, 1.0, 1.0, 0.675)


@export_group("Obrażenia i Porażenie (CC)")
## Bazowe obrażenia (HP) zadawane przez uderzenie ogonem.
@export_range(0, 150, 1) var tail_damage: int = 35

## Czy uderzenie ogonem ma ogłuszać ofiarę, blokując jej możliwość ruchu i ataku?
@export var apply_stun: bool = true

## Czas trwania nałożonego ogłuszenia (w sekundach).
@export_range(0.1, 5.0, 0.1) var stun_time: float = 1.5


@export_group("Efekt: Odrzut (Knockback)")
## Czy uderzenie ma fizycznie odrzucać ofiarę do tyłu (Knockback)?
@export var apply_knockback: bool = true

## Siła odrzutu w pikselach. Im większa wartość, tym gwałtowniej ofiara odleci po otrzymaniu ciosu.
@export_range(100.0, 3000.0, 50.0) var knockback_force: float = 1200.0

## Czas (w sekundach), przez jaki ofiara traci kontrolę podczas bezwładnego lotu do tyłu.
@export_range(0.1, 1.0, 0.1) var knockback_duration: float = 0.7


@export_group("Efekt: Jad / Kwas")
## Czy ostre kolce/kwas na ogonie mają nakładać na ofiarę efekt trucizny (obrażenia w czasie)?
@export var apply_poison: bool = false

## Ilość obrażeń zadawanych co dokładnie 1 sekundę przez czas trwania trucizny.
@export_range(1, 20, 1) var poison_damage_per_tick: int = 3

## Całkowity czas trwania efektu zatrucia kwasem (w sekundach).
@export_range(1.0, 15.0, 1.0) var poison_duration: float = 5.0


func _init() -> void:
	ability_name = "Bioniczny Ogon i Porażenie"
	cooldown = 7.0
	min_range = 0.0
	max_range = 120.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl: combat_ctrl.is_casting_ability = true

	var start_position = attacker.global_position
	var aim_direction = attacker.global_position.direction_to(target.global_position)
	var tail_direction = -aim_direction 
	
	# =========================================================
	# FAZA 1: TELEGRAFOWANIE 
	# =========================================================
	if can_rotate:
		var rot_tween = attacker.create_tween()
		rot_tween.tween_property(attacker, "rotation", tail_direction.angle(), telegraph_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if attacker.has_method("_update_sprite_direction"):
			attacker._update_sprite_direction(tail_direction)

	await attacker.get_tree().create_timer(telegraph_time).timeout
	if not is_instance_valid(attacker) or not is_instance_valid(target): return

	# =========================================================
	# FAZA 2: BEZPIECZNY DOSKOK DO GRACZA
	# =========================================================
	aim_direction = attacker.global_position.direction_to(target.global_position)
	var original_pos = attacker.global_position
	
	# Obliczanie krawędzi
	var attacker_rad = attacker.combat_radius if "combat_radius" in attacker else 40.0
	var target_rad = target.combat_radius if "combat_radius" in target else 40.0
	var edge_distance = max(0.0, original_pos.distance_to(target.global_position) - (attacker_rad + target_rad))
	
	var actual_dash_distance = min(dash_distance, edge_distance)
	var move_vec = aim_direction * actual_dash_distance
	
	var col = attacker.move_and_collide(move_vec, true)
	var forward_pos = original_pos + move_vec
	
	if col:
		forward_pos = original_pos + col.get_travel()
	
	var dash_tween = attacker.create_tween()
	dash_tween.tween_property(attacker, "global_position", forward_pos, dash_forward_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	await attacker.get_tree().create_timer(dash_forward_time).timeout
	if not is_instance_valid(attacker): return

	# =========================================================
	# FAZA 3: CIĄGŁY, PEŁNY OBRÓT (540 Stopni) I UDERZENIE
	# =========================================================
	var total_spin_angle = TAU * spin_rotations 
	
	var slash_visual = TailSlashVisual.new()
	slash_visual.radius = slash_radius
	slash_visual.color = slash_color
	slash_visual.core_color = slash_core_color
	slash_visual.duration = slash_duration
	slash_visual.total_angle = total_spin_angle
	slash_visual.target_node = attacker
	slash_visual.z_index = slash_z_index
	slash_visual.z_as_relative = false
	
	# BEZPIECZNE SPAWNOWANIE (W oparciu o Menedżera Mapy)
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", slash_visual, attacker.global_position)
	else:
		var parent_node = attacker.get_parent()
		if parent_node:
			parent_node.add_child(slash_visual)
			slash_visual.global_position = attacker.global_position
		else:
			attacker.get_tree().current_scene.add_child(slash_visual)
			slash_visual.global_position = attacker.global_position

	var spin_tween = attacker.create_tween()
	
	if can_rotate:
		spin_tween.tween_property(attacker, "rotation", attacker.rotation + total_spin_angle, slash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		spin_tween.tween_method(
			func(angle_offset: float):
				if is_instance_valid(attacker) and attacker.has_method("_update_sprite_direction"):
					var current_spin_dir = tail_direction.rotated(angle_offset)
					attacker._update_sprite_direction(current_spin_dir), 0.0, total_spin_angle, slash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await attacker.get_tree().create_timer(slash_duration * 0.3).timeout
	if not is_instance_valid(attacker): return

	var space_state = attacker.get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = slash_radius
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, attacker.global_position)
	query.exclude = [attacker.get_rid()]
	
	var hits = space_state.intersect_shape(query, 16)
	var effects_to_apply: Array[Effect] = []
	
	if tail_damage > 0: effects_to_apply.append(DamageEffect.new(tail_damage))
	if apply_knockback: effects_to_apply.append(KnockbackEffect.new(knockback_force, knockback_duration))
	if apply_stun: effects_to_apply.append(StunEffect.new(stun_time))
	if apply_poison:
		var poison = PoisonEffect.new()
		poison.effect_name = "Kwas Z Ogonu"
		poison.poison_damage_per_tick = poison_damage_per_tick
		poison.duration = poison_duration
		effects_to_apply.append(poison)

	var hit_anyone = false

	for hit in hits:
		var hit_collider = hit.collider
		if not is_instance_valid(hit_collider): continue
		if not friendly_fire and _is_ally(attacker, hit_collider as Node2D): continue
		
		if hit_collider.has_method("receive_effect"):
			hit_anyone = true
			_flash_target_red(hit_collider as Node2D)
			
			for eff in effects_to_apply:
				var cloned_eff = eff.duplicate(true)
				cloned_eff.source_entity = attacker
				cloned_eff.source_position = attacker.global_position
				hit_collider.receive_effect(cloned_eff)

	if hit_anyone:
		var cam = attacker.get_tree().current_scene.get_node_or_null("CameraComponent")
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.6)

	var remaining_spin_time = slash_duration - (slash_duration * 0.3)
	await attacker.get_tree().create_timer(remaining_spin_time).timeout
	if not is_instance_valid(attacker): return

	# =========================================================
	# FAZA 4: POWRÓT NA MIEJSCE (Jeśli włączone)
	# =========================================================
	if return_to_original_position:
		var ret_tween = attacker.create_tween()
		ret_tween.tween_property(attacker, "global_position", start_position, dash_return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await ret_tween.finished

	if is_instance_valid(attacker) and is_instance_valid(target):
		var face_direction = attacker.global_position.direction_to(target.global_position)
		if can_rotate:
			attacker.rotation = face_direction.angle()
		elif attacker.has_method("_update_sprite_direction"):
			attacker._update_sprite_direction(face_direction)

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false

func _is_ally(attacker: Node2D, target: Node2D) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return false
	var attacker_faction = attacker.get_node_or_null("FactionComponent")
	if attacker_faction and target is CharacterEntity:
		return attacker_faction.get_disposition_toward(target) == FactionComponent.Disposition.FRIENDLY
	return false

func _flash_target_red(target_node: Node2D) -> void:
	if not is_instance_valid(target_node): return
	var spr = target_node.get_node_or_null("Sprite2D")
	if target_node.get("character_sprite"): spr = target_node.character_sprite
	
	if spr:
		var orig = spr.self_modulate
		spr.self_modulate = Color.RED
		var tw = target_node.create_tween()
		tw.tween_property(spr, "self_modulate", orig, 0.3)


# ==============================================================================
# KLASA WEWNĘTRZNA: Dynamiczne rysowanie cięcia w powietrzu (Slash)
# ==============================================================================
class TailSlashVisual extends Node2D:
	var radius: float = 80.0
	var color: Color = Color.GREEN
	var core_color: Color = Color.WHITE
	var duration: float = 0.3
	var total_angle: float = TAU
	var elapsed: float = 0.0
	var target_node: Node2D = null

	func _ready() -> void:
		rotation = randf_range(0, TAU)

	func _process(delta: float) -> void:
		if not is_instance_valid(target_node):
			queue_free()
			return
			
		# Obiekt zawsze podąża dokładnie za postacią, nawet po wyspawnowaniu w Mapie
		global_position = target_node.global_position
		
		elapsed += delta
		rotation += (total_angle / duration) * delta
		queue_redraw()
		
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var progress = clamp(elapsed / duration, 0.0, 1.0)
		
		var thickness = lerp(radius * 0.5, 0.0, progress)
		var current_radius = lerp(radius * 0.4, radius * 0.9, progress)
		var alpha = lerp(1.0, 0.0, progress)
		
		var draw_color = Color(color.r, color.g, color.b, alpha)
		var final_core = Color(core_color.r, core_color.g, core_color.b, alpha)
		
		draw_arc(Vector2.ZERO, current_radius, -PI, PI * 0.6, 32, draw_color, thickness)
		draw_arc(Vector2.ZERO, current_radius, -PI, PI * 0.6, 32, final_core, thickness * 0.3)
