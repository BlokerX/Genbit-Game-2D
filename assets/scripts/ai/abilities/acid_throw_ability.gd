extends AIAbility
class_name AcidThrowAbility

@export_category("Zdolność: Rzut Kwasem")

@export_group("Czasy Trwania i Zasięg")
## Czas, w którym potwór "zbiera ślinę" (zmienia kolor na zielony) przed rzutem.
@export_range(0.1, 2.0, 0.1) var telegraph_time: float = 1.3
## Czas lotu kuli kwasu do celu. Im mniej, tym szybszy rzut.
@export_range(0.1, 2.0, 0.1) var flight_time: float = 1
## Przewidywanie ruchu gracza (0.0 = rzuca tam gdzie stoi, 1.0 = rzuca z silnym wyprzedzeniem).
@export_range(0.0, 1.5, 0.1) var prediction_factor: float = 0.6
## Maska fizyki dla ŚCIAN/PRZESZKÓD, na których kula kwasu rozbije się przedwcześnie w locie.
@export_flags_2d_physics var obstacles_mask: int = 1 

@export_group("Wizualizacje i Obszar (AoE)")
## Główny kolor kwasu (domyślnie toksyczna zieleń).
@export var acid_color: Color = Color(0.2, 0.9, 0.1, 0.85)
## Promień fizyczny i wizualny kuli w trakcie lotu.
@export_range(10.0, 100.0, 5.0) var blob_radius: float = 20.0
## Zasięg (promień) rozlanej kałuży po uderzeniu w ziemię.
@export_range(30.0, 300.0, 10.0) var puddle_radius: float = 450.0
## Czas (w sekundach), przez jaki kałuża utrzymuje się na ziemi.
@export_range(1.0, 20.0, 0.5) var puddle_lifetime: float = 7.0
## Czy uderzenie i kałuża mają wpływać również na innych wrogów (sojuszników atakującego)?
@export var friendly_fire: bool = false

@export_group("Efekt: Uderzenie (Kula)")
## Natychmiastowe obrażenia zadawane w momencie wybuchu kuli na ziemi (przed rozlaniem kałuży).
@export_range(0, 100, 1) var impact_damage: int = 20
## Wstrząs kamery w momencie rozbicia się kwasu o ziemię.
@export_range(0.0, 1.0, 0.1) var impact_camera_shake: float = 0.4

@export_group("Efekt: Kałuża Kwasu (AoE)")
## Jak często (w sekundach) kałuża zadaje obrażenia/nakłada statusy na istoty stojące w środku.
@export_range(0.1, 2.0, 0.1) var puddle_tick_rate: float = 0.5
## Czy wejście w kałużę nakłada status trucizny (obrażenia w czasie)?
@export var apply_poison: bool = true
## Ilość obrażeń od trucizny zadawanych na każdy jej tik.
@export_range(1, 30, 1) var poison_damage_per_tick: int = 4
## Czas działania nałożonej trucizny po wyjściu z kałuży.
@export_range(1.0, 15.0, 1.0) var poison_duration: float = 4.0

@export_group("Efekt: Lepki Szlam (CC)")
## Czy stanie w kwasie drastycznie spowalnia cel?
@export var apply_slow: bool = false
## Czas trwania spowolnienia nałożonego przez kałużę.
@export_range(0.5, 10.0, 0.5) var slow_duration: float = 3.0
## Siła spowolnienia (0.2 oznacza zwolnienie postaci do 20% jej maksymalnej prędkości).
@export_range(0.1, 0.9, 0.1) var slow_multiplier: float = 0.3 

func _init() -> void:
	ability_name = "Rzut Kwasem"
	cooldown = 10.0
	min_range = 0
	max_range = 700.0

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target): return
	var ai_controller = attacker.get_node_or_null("AIController")
	var combat_ctrl = ai_controller.get_node_or_null("AICombatController") if ai_controller else null
	
	var can_rotate = false
	if ai_controller and ai_controller.get("behavior_profile") != null:
		can_rotate = ai_controller.behavior_profile.can_rotate_to_target

	if combat_ctrl: combat_ctrl.is_casting_ability = true

	# Zapisujemy oryginalne kolory
	var sprite = attacker.get_node_or_null("Sprite2D")
	if attacker.get("character_sprite"): sprite = attacker.character_sprite
	var orig_modulate = Color.WHITE
	if sprite: orig_modulate = sprite.self_modulate

	# =========================================================
	# FAZA 1: TELEGRAFOWANIE (Nabieranie kwasu)
	# =========================================================
	var aim_direction = attacker.global_position.direction_to(target.global_position)
	if can_rotate:
		var rot_tween = attacker.create_tween()
		rot_tween.tween_property(attacker, "rotation", aim_direction.angle(), telegraph_time * 0.8)
	else:
		if attacker.has_method("_update_sprite_direction"):
			attacker._update_sprite_direction(aim_direction)

	# Zmiana koloru na toksyczną zieleń (BEZ SKALOWANIA)
	if sprite:
		var visual_tween = attacker.create_tween()
		var target_color = orig_modulate.lerp(acid_color, 0.7)
		visual_tween.tween_property(sprite, "self_modulate", target_color, telegraph_time).set_trans(Tween.TRANS_SINE)
		
	await attacker.get_tree().create_timer(telegraph_time).timeout
	
	if sprite and is_instance_valid(sprite): 
		sprite.self_modulate = orig_modulate

	if not is_instance_valid(attacker) or not is_instance_valid(target): return

	# =========================================================
	# FAZA 2: RZUT I LOT POCISKU (Obliczanie trajektorii)
	# =========================================================
	var start_pos = attacker.global_position
	var predicted_pos = target.global_position
	if "velocity" in target and target.velocity != Vector2.ZERO:
		predicted_pos += target.velocity * prediction_factor
		
	# Limitujemy zasięg strzału
	if start_pos.distance_to(predicted_pos) > max_range:
		predicted_pos = start_pos + start_pos.direction_to(predicted_pos) * max_range

	# Sprawdzanie przeszkód (żeby nie przerzucić kwasu przez ścianę)
	var space_state = attacker.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, predicted_pos)
	query.collision_mask = obstacles_mask
	query.exclude = [attacker.get_rid()]
	var result = space_state.intersect_ray(query)
	var final_target_pos = result.position if result else predicted_pos

	# Tworzymy niezależny, fizyczny i wizualny pocisk kwasu
	var acid_projectile = AcidProjectileLogic.new()
	acid_projectile.setup(
		attacker, start_pos, final_target_pos, flight_time, 
		acid_color, blob_radius, puddle_radius, puddle_lifetime, puddle_tick_rate,
		impact_damage, apply_poison, poison_damage_per_tick, poison_duration,
		apply_slow, slow_duration, slow_multiplier, friendly_fire, impact_camera_shake
	)
	attacker.get_tree().current_scene.add_child(acid_projectile)

	if is_instance_valid(attacker) and combat_ctrl:
		combat_ctrl.is_casting_ability = false

# ==============================================================================
# KLASA WEWNĘTRZNA: Obsługa lotu, wybuchu i samej kałuży
# ==============================================================================
class AcidProjectileLogic extends Node2D:
	var attacker_ref: Node2D
	var start_pos: Vector2
	var target_pos: Vector2
	var flight_duration: float
	
	var a_color: Color
	var b_radius: float
	var p_radius: float
	var p_lifetime: float
	var p_tick_rate: float
	
	var i_dmg: int
	var a_poison: bool
	var p_dmg: int
	var p_dur: float
	var a_slow: bool
	var s_dur: float
	var s_mult: float
	var f_fire: bool
	var cam_shake: float

	var elapsed: float = 0.0
	var is_puddle: bool = false
	var tick_timer: float = 0.0

	func setup(
		_attacker, _start, _target, _flight_dur,
		_col, _blob_rad, _puddle_rad, _puddle_life, _tick_rate,
		_impact_dmg, _apply_pois, _pois_dmg, _pois_dur,
		_apply_slw, _slw_dur, _slw_mult, _friendly_fire, _cam_shake
	) -> void:
		attacker_ref = _attacker
		start_pos = _start
		target_pos = _target
		flight_duration = _flight_dur
		
		a_color = _col
		b_radius = _blob_rad
		p_radius = _puddle_rad
		p_lifetime = _puddle_life
		p_tick_rate = _tick_rate
		
		i_dmg = _impact_dmg
		a_poison = _apply_pois
		p_dmg = _pois_dmg
		p_dur = _pois_dur
		a_slow = _apply_slw
		s_dur = _slw_dur
		s_mult = _slw_mult
		f_fire = _friendly_fire
		cam_shake = _cam_shake
		
		global_position = start_pos

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		
		if not is_puddle:
			var progress = clamp(elapsed / flight_duration, 0.0, 1.0)
			global_position = start_pos.lerp(target_pos, progress)
			
			if progress >= 1.0:
				_explode_on_impact()
		else:
			tick_timer += delta
			if tick_timer >= p_tick_rate:
				tick_timer = 0.0
				_apply_puddle_effects()
				
			if elapsed >= flight_duration + p_lifetime:
				queue_free()

	func _draw() -> void:
		if not is_puddle:
			var progress = clamp(elapsed / flight_duration, 0.0, 1.0)
			var arc_scale = 1.0 + (sin(progress * PI) * 0.8) 
			
			var draw_rad = b_radius * arc_scale
			draw_circle(Vector2.ZERO, draw_rad, a_color)
			
			var core_col = a_color.lightened(0.4)
			draw_circle(Vector2.ZERO, draw_rad * 0.4, core_col)
			
			draw_circle(target_pos - global_position, draw_rad * 0.8, Color(0,0,0, 0.3 * (1.0-progress)))
			
		else:
			var puddle_progress = clamp((elapsed - flight_duration) / p_lifetime, 0.0, 1.0)
			
			var size_mult = 1.0
			var alpha_mult = 1.0
			
			if puddle_progress < 0.1:
				size_mult = lerp(0.2, 1.0, puddle_progress * 10.0) 
			elif puddle_progress > 0.8:
				alpha_mult = lerp(1.0, 0.0, (puddle_progress - 0.8) * 5.0) 
				
			var current_radius = p_radius * size_mult
			var p_color = Color(a_color.r, a_color.g, a_color.b, a_color.a * 0.6 * alpha_mult)
			var border_color = Color(a_color.r, a_color.g, a_color.b, a_color.a * 0.9 * alpha_mult)
			
			var time_ms = Time.get_ticks_msec() * 0.005
			var ripple = sin(time_ms) * (current_radius * 0.05)
			
			draw_circle(Vector2.ZERO, current_radius + ripple, p_color)
			draw_arc(Vector2.ZERO, current_radius + ripple, 0, TAU, 32, border_color, 4.0)

	func _explode_on_impact() -> void:
		is_puddle = true
		
		if cam_shake > 0.0:
			var cam = get_tree().current_scene.get_node_or_null("CameraComponent")
			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(cam_shake)
				
		if i_dmg > 0:
			var effects = [DamageEffect.new(i_dmg)]
			_apply_aoe_effects(b_radius * 1.5, effects) 
			
		_apply_puddle_effects()

	func _apply_puddle_effects() -> void:
		var effects: Array[Effect] = []
		
		if a_poison:
			var poison = PoisonEffect.new()
			poison.effect_name = "Kwasowa Zgnilizna"
			poison.poison_damage_per_tick = p_dmg
			poison.duration = p_dur
			effects.append(poison)
			
		if a_slow:
			var slow = SlowEffect.new(s_dur, s_mult)
			slow.effect_name = "Lepki Szlam"
			effects.append(slow)
			
		if effects.size() > 0:
			_apply_aoe_effects(p_radius, effects)

	func _apply_aoe_effects(radius_to_check: float, effects_to_apply: Array) -> void:
		var space_state = get_world_2d().direct_space_state
		var shape = CircleShape2D.new()
		shape.radius = radius_to_check
		
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, global_position)
		
		var hits = space_state.intersect_shape(query, 32)
		for hit in hits:
			var col = hit.collider
			if not is_instance_valid(col): continue
			
			if not f_fire and is_instance_valid(attacker_ref):
				var attacker_faction = attacker_ref.get_node_or_null("FactionComponent")
				if attacker_faction and col is CharacterEntity:
					if attacker_faction.get_disposition_toward(col) == FactionComponent.Disposition.FRIENDLY:
						continue
			
			if col.has_method("receive_effect"):
				for eff in effects_to_apply:
					var cloned_eff = eff.duplicate(true)
					cloned_eff.source_entity = attacker_ref if is_instance_valid(attacker_ref) else null
					cloned_eff.source_position = global_position
					col.receive_effect(cloned_eff)
