extends AIAbility
class_name JumpSmashAbility

@export var damage: int = 30
@export var stun_duration: float = 1.5
@export var knockback_force: float = 800.0 ## <--- NOWA ZMIENNA (Siła odrzutu)
@export var aoe_radius: float = 80.0
@export var cast_time: float = 1.2      ## Całkowity czas od momentu narysowania plamy do wybuchu
@export var jump_duration: float = 0.5  ## Czas samego lotu (zawsze musi być mniejszy niż cast_time!)
@export var recovery_time: float = 0.5  ## Odpoczynek bossa po skoku
@export_flags_2d_physics var obstacles_mask: int = 1 ## Warstwa fizyki, na której są ściany

func _init():
	ability_name = "Miażdżący Skok"
	cooldown = 8.0
	min_range = 50.0
	max_range = 250.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	var combat_ctrl = attacker.get_node_or_null("AIController/AICombatController")
	if combat_ctrl:
		combat_ctrl.is_casting_ability = true

	var raw_target_pos = target.global_position
	var safe_target_pos = raw_target_pos
	
	var space_state = attacker.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(attacker.global_position, raw_target_pos)
	query.collision_mask = obstacles_mask
	query.exclude = [attacker.get_rid(), target.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	if result:
		var dir = attacker.global_position.direction_to(raw_target_pos)
		safe_target_pos = result.position - (dir * 30.0) 

	var aoe = TelegraphedAOE.new()
	var dmg_eff = DamageEffect.new(damage)
	var stun_eff = StunEffect.new(stun_duration)
	var knock_eff = KnockbackEffect.new(knockback_force) # <--- TWORZYMY EFEKT ODRZUTU
	
	# Dodajemy 'knock_eff' do tablicy efektów!
	aoe.setup(safe_target_pos, aoe_radius, cast_time, [dmg_eff, stun_eff, knock_eff], attacker, target)
	
	attacker.get_tree().current_scene.add_child(aoe)
	print(attacker.name + " ładuje skok! Gracz ma " + str(cast_time) + "s na unik!")

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
				cam.add_trauma(0.4)
		await attacker.get_tree().create_timer(recovery_time).timeout

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false
