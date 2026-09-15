extends AIAbility
class_name JumpSmashAbility

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
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	var combat_ctrl = attacker.get_node_or_null("AIController/AICombatController")
	if combat_ctrl:
		combat_ctrl.is_casting_ability = true

	# --- 1. PRZEWIDYWANIE RUCHU CELU ---
	var predicted_pos = target.global_position
	if "velocity" in target and target.velocity != Vector2.ZERO:
		predicted_pos += target.velocity * prediction_factor
		
	# Zabezpieczenie: Boss nie może skoczyć w przewidziane miejsce, jeśli przekracza to jego maksymalny zasięg
	var dist_to_prediction = attacker.global_position.distance_to(predicted_pos)
	if dist_to_prediction > max_range:
		predicted_pos = attacker.global_position + attacker.global_position.direction_to(predicted_pos) * max_range

	# --- 2. WYLICZANIE POZYCJI LĄDOWANIA ---
	var dir_to_target = attacker.global_position.direction_to(predicted_pos)
	var raw_target_pos = predicted_pos
	var safe_target_pos = raw_target_pos
	
	# Zabezpieczenie przed skokiem w ścianę (w drodze do przewidzianego miejsca)
	var space_state = attacker.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(attacker.global_position, raw_target_pos)
	query.collision_mask = obstacles_mask
	query.exclude = [attacker.get_rid(), target.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	if result:
		var attacker_rad = attacker.combat_radius if "combat_radius" in attacker else 40.0
		# Jeśli ściana jest na drodze do celu, skracamy lot, aby w nią nie wpaść
		safe_target_pos = result.position - (dir_to_target * (attacker_rad + 5.0))

	# --- 3. SPAWNOWANIE PLAMY I ANIMACJA ---
	var aoe = TelegraphedAOE.new()
	var dmg_eff = DamageEffect.new(damage)
	var stun_eff = StunEffect.new(stun_duration)
	var knock_eff = KnockbackEffect.new(knockback_force)
	
	aoe.setup(safe_target_pos, aoe_radius, cast_time, [dmg_eff, stun_eff, knock_eff], attacker, target)
	
	aoe.z_index = aoe_z_index
	aoe.z_as_relative = false
	if "danger_color" in aoe:
		aoe.danger_color = aoe_danger_color
	
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", aoe, safe_target_pos)
	else:
		var parent_node = attacker.get_parent()
		if parent_node:
			parent_node.add_child(aoe)
			aoe.global_position = safe_target_pos
		else:
			attacker.get_tree().current_scene.add_child(aoe)
			aoe.global_position = safe_target_pos

	var windup_time = max(0.0, cast_time - jump_duration)
	if windup_time > 0.0:
		await attacker.get_tree().create_timer(windup_time).timeout

	if not is_instance_valid(attacker) or not attacker.is_inside_tree(): return
	var original_scale = attacker.scale
	
	var pos_tween = attacker.create_tween()
	pos_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pos_tween.tween_property(attacker, "global_position", safe_target_pos, jump_duration)
	
	var scale_tween = attacker.create_tween()
	var scale_up_time = jump_duration * 0.5
	var scale_down_time = jump_duration * 0.5
	scale_tween.tween_property(attacker, "scale", original_scale * 1.35, scale_up_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(attacker, "scale", original_scale, scale_down_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await pos_tween.finished

	if recovery_time > 0.0:
		if is_instance_valid(attacker):
			var cam = attacker.get_tree().current_scene.get_node_or_null("CameraComponent")
			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(camera_trauma_amount)
		await attacker.get_tree().create_timer(recovery_time).timeout

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false
