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
@export_range(30.0, 300.0, 10.0) var puddle_radius: float = 600.0
## Czas (w sekundach), przez jaki kałuża utrzymuje się na ziemi.
@export_range(1.0, 20.0, 0.5) var puddle_lifetime: float = 7.0
## Czy uderzenie i kałuża mają wpływać również na innych wrogów (sojuszników atakującego)?
@export var friendly_fire: bool = false
## Z-Index (warstwa rysowania) dla kałuży. Domyślnie 0.
@export var puddle_z_index: int = GameLayers.FLOOR_HAZARD

@export_group("Kształt Kałuży (Organic Puddle)")
## Częstotliwość szumu (niższa wartość = szersze, łagodniejsze fale na krawędziach).
@export_range(0.005, 0.1, 0.005) var noise_frequency: float = 0.025
## Siła zniekształcenia (jak bardzo plama odchyla się od idealnego koła, 0.12 to 12% rozrzutu).
@export_range(0.0, 0.5, 0.01) var noise_amplitude: float = 0.2
## Szybkość deformacji (pływania) krawędzi plamy. Ustaw na 0.0, aby kształt był całkowicie statyczny.
@export_range(0.0, 50.0, 0.5) var noise_speed: float = 0.1
## Ilość punktów tworzących krawędź plamy (więcej = gładsza, ale nieco droższa w obliczeniach).
@export_range(16, 128, 1) var polygon_resolution: int = 120
## Ilość przejść algorytmu wygładzającego (Moving Average). Zmiękcza ostre kąty powstałe z szumu i kolizji.
@export_range(0, 5, 1) var smoothing_iterations: int = 2
## Szybkość pulsowania (oddychania) plamy. 0.0 zatrzymuje pulsowanie.
@export_range(0.0, 20.0, 0.5) var puddle_pulse_speed: float = 0.5
## Siła pulsowania (0.02 oznacza, że promień zmienia się o +/- 2%).
@export_range(0.0, 0.2, 0.01) var puddle_pulse_strength: float = 0.01
## Skala wewnętrznego rdzenia kałuży (0.6 oznacza, że środek zajmuje 60% plamy). Ustaw na 1.0, aby ukryć obramowanie.
@export_range(0.0, 1.0, 0.05) var visual_core_scale: float = 1
## Czas w sekundach, w jakim plama rozlewa się do pełnego rozmiaru po uderzeniu w ziemię.
@export_range(0.1, 5.0, 0.1) var puddle_spill_time: float = 0.4
## Czas w sekundach na końcu życia plamy, podczas którego płynnie zanika (zanika przezroczystość).
@export_range(0.1, 5.0, 0.1) var puddle_fade_time: float = 1.8
## Grubość obrysowania krawędzi plamy.
@export_range(0.0, 10.0, 0.5) var puddle_outline_thickness: float = 0

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
## Siła spowolnienia (0.2 oznacza zwolnienie postaci do 20% jej maksymal prędkości).
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
		apply_slow, slow_duration, slow_multiplier, friendly_fire, impact_camera_shake,
		obstacles_mask,
		noise_frequency, noise_amplitude, noise_speed, polygon_resolution, smoothing_iterations,
		puddle_pulse_speed, puddle_pulse_strength, visual_core_scale,
		puddle_spill_time, puddle_fade_time, puddle_outline_thickness,
		puddle_z_index
	)
	
	if attacker.has_signal("entity_spawn_requested"):
		attacker.emit_signal("entity_spawn_requested", acid_projectile, start_pos)
	else:
		var parent_node = attacker.get_parent()
		if parent_node:
			parent_node.add_child(acid_projectile)
			acid_projectile.global_position = start_pos
		else:
			attacker.get_tree().current_scene.add_child(acid_projectile)
			acid_projectile.global_position = start_pos

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
	
	var o_mask: int = 1
	var n_freq: float
	var n_amp: float
	var n_spd: float
	var poly_res: int
	var smooth_iter: int
	var p_pulse_spd: float
	var p_pulse_str: float
	var p_core_scale: float
	
	var p_spill_time: float
	var p_fade_time: float
	var p_outline_thick: float
	
	var puddle_polygon: PackedVector2Array = []
	var inner_puddle_polygon: PackedVector2Array = [] 
	var puddle_noise: FastNoiseLite 

	var elapsed: float = 0.0
	var is_puddle: bool = false
	var tick_timer: float = 0.0

	func setup(
		_attacker, _start, _target, _flight_dur,
		_col, _blob_rad, _puddle_rad, _puddle_life, _tick_rate,
		_impact_dmg, _apply_pois, _pois_dmg, _pois_dur,
		_apply_slw, _slw_dur, _slw_mult, _friendly_fire, _cam_shake,
		_obstacles_mask: int,
		_noise_freq: float, _noise_amp: float, _noise_spd: float, _poly_res: int, _smooth_iter: int,
		_pulse_spd: float, _pulse_str: float, _core_scale: float,
		_spill_time: float, _fade_time: float, _outline_thick: float,
		_z_index: int
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
		o_mask = _obstacles_mask
		
		n_freq = _noise_freq
		n_amp = _noise_amp
		n_spd = _noise_spd
		poly_res = _poly_res
		smooth_iter = _smooth_iter
		p_pulse_spd = _pulse_spd
		p_pulse_str = _pulse_str
		p_core_scale = _core_scale
		
		p_spill_time = _spill_time
		p_fade_time = _fade_time
		p_outline_thick = _outline_thick
		
		z_index = _z_index 
		
		puddle_noise = FastNoiseLite.new()
		puddle_noise.seed = randi()
		puddle_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		puddle_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		puddle_noise.fractal_octaves = 2
		puddle_noise.frequency = n_freq 
		
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
			
			_update_puddle_polygon()
				
			if elapsed >= flight_duration + p_lifetime:
				queue_free()

	func _update_puddle_polygon() -> void:
		var puddle_elapsed = elapsed - flight_duration
		var size_mult = 1.0
		
		if p_spill_time > 0.0 and puddle_elapsed < p_spill_time:
			size_mult = lerp(0.1, 1.0, clamp(puddle_elapsed / p_spill_time, 0.0, 1.0))
			
		var current_radius = p_radius * size_mult
		var time_sec = Time.get_ticks_msec() * 0.001
		var ripple = sin(time_sec * p_pulse_spd) * (current_radius * p_pulse_str)
		var final_radius = current_radius + ripple
		
		var raw_polygon = PackedVector2Array()
		var raw_inner_polygon = PackedVector2Array()
		var space_state = get_world_2d().direct_space_state
		
		for i in range(poly_res):
			var angle = (i / float(poly_res)) * TAU
			var dir = Vector2.RIGHT.rotated(angle)
			
			var nx = cos(angle) * 50.0
			var ny = sin(angle) * 50.0
			var nz = elapsed * n_spd
			var noise_val = puddle_noise.get_noise_3d(nx, ny, nz)
			
			var organic_mult = 1.0 + (noise_val * n_amp)
			var organic_radius = final_radius * organic_mult
			
			var max_point = global_position + (dir * organic_radius)
			
			var query = PhysicsRayQueryParameters2D.create(global_position, max_point)
			query.collision_mask = o_mask
			if is_instance_valid(attacker_ref) and attacker_ref is CollisionObject2D:
				query.exclude = [attacker_ref.get_rid()]
				
			var result = space_state.intersect_ray(query)
			var edge_point: Vector2
			if result:
				edge_point = to_local(result.position - dir * 1.0)
			else:
				edge_point = to_local(max_point)
				
			raw_polygon.append(edge_point)
			raw_inner_polygon.append(edge_point * p_core_scale)

		for iteration in range(smooth_iter): 
			var temp_poly = PackedVector2Array()
			var temp_inner = PackedVector2Array()
			var c = raw_polygon.size()
			
			for i in range(c):
				var prev = raw_polygon[(i - 1 + c) % c]
				var curr = raw_polygon[i]
				var next = raw_polygon[(i + 1) % c]
				temp_poly.append((prev + curr * 2.0 + next) / 4.0)

				var in_prev = raw_inner_polygon[(i - 1 + c) % c]
				var in_curr = raw_inner_polygon[i]
				var in_next = raw_inner_polygon[(i + 1) % c]
				temp_inner.append((in_prev + in_curr * 2.0 + in_next) / 4.0)

			raw_polygon = temp_poly
			raw_inner_polygon = temp_inner
			
		puddle_polygon = raw_polygon
		inner_puddle_polygon = raw_inner_polygon

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
			var puddle_elapsed = elapsed - flight_duration
			var time_left = p_lifetime - puddle_elapsed
			var alpha_mult = 1.0
			
			if p_fade_time > 0.0 and time_left < p_fade_time:
				alpha_mult = clamp(time_left / p_fade_time, 0.0, 1.0)
				
			var p_color = Color(a_color.r, a_color.g, a_color.b, a_color.a * 0.5 * alpha_mult)
			var core_color = Color(a_color.r, a_color.g, a_color.b, a_color.a * 0.8 * alpha_mult)
			var border_color = Color(a_color.r, a_color.g, a_color.b, a_color.a * 0.9 * alpha_mult)
			
			if puddle_polygon.size() >= 3:
				draw_colored_polygon(puddle_polygon, p_color)
				if p_core_scale > 0.0:
					draw_colored_polygon(inner_puddle_polygon, core_color)
				
				var outline = puddle_polygon.duplicate()
				outline.append(outline[0])
				
				if p_outline_thick > 0.0:
					draw_polyline(outline, border_color, p_outline_thick)

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
			
			var los_query = PhysicsRayQueryParameters2D.create(global_position, col.global_position)
			los_query.collision_mask = o_mask
			
			var excludes = []
			if col.has_method("get_rid"):
				excludes.append(col.get_rid())
			if is_instance_valid(attacker_ref) and attacker_ref.has_method("get_rid"):
				excludes.append(attacker_ref.get_rid())
				
			los_query.exclude = excludes
			
			var los_result = space_state.intersect_ray(los_query)
			if los_result and los_result.collider != col:
				continue
			
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
