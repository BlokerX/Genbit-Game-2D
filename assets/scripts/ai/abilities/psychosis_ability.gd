extends AIAbility
class_name PsychosisAbility

const MAX_PSYCHOSIS_HITS: int = 32
const HALF_CAST_FACTOR: float = 0.5

@export_category("Zdolność: Psychoza")

@export_group("Celowanie i Zasięg (Fale AOE)")
@export_range(0.1, 5.0, 0.1) var cast_time: float = 1.2
## Zasięg, w którym fala dotyka ofiar (zostanie narysowana na ziemi)
@export_range(50.0, 1500.0, 10.0) var blast_radius: float = 450.0
@export var friendly_fire: bool = false

@export_group("Wizualizacje Rzucania")
@export var aura_color: Color = Color(0.4, 0.0, 0.8, 0.6) # Mroczny fiolet
@export_range(1.0, 3.0, 0.1) var visual_scale_pulse: float = 1.3
## Czas zanikania fali po eksplozji (dla efektu wizualnego)
@export_range(0.1, 1.0, 0.1) var explosion_fade_time: float = 0.8
## Z-Index (warstwa rysowania) dla fali na ziemi. Domyślnie -10 (pod postaciami).
@export var wave_z_index: int = -10

@export_group("Efekt: Zamrożenie (Szok Mentalny)")
@export var apply_freeze: bool = true
## Czas całkowitego paraliżu wejść gracza
@export_range(0.1, 5.0, 0.1) var freeze_duration: float = 1.5

@export_group("Efekt: Ciężki Stun i Spowolnienie")
@export var apply_stun: bool = true
@export_range(0.1, 10.0, 0.5) var stun_duration: float = 4.0
@export var apply_slow: bool = true
@export_range(0.5, 20.0, 0.5) var slow_duration: float = 6.0
## 0.1 to 10% oryginalnej prędkości, 0.9 to 90%
@export_range(0.1, 0.9, 0.1) var slow_multiplier: float = 0.35 

@export_group("Efekt: Mgła, Zaciemnienie i Nudności (Tylko Gracz)")
@export var apply_mental_fog: bool = true
@export var fog_color: Color = Color(0.05, 0.0, 0.1, 0.95) # Prawie smolista ciemność
@export_range(1.0, 15.0, 0.5) var fog_duration: float = 5.0
@export var apply_screen_shake: bool = true
@export_range(0.1, 2.0, 0.1) var camera_trauma_amount: float = 0.85
## Warstwa CanvasLayer dla mgły zasłaniającej ekran. Domyślnie 90.
@export var fog_canvas_layer: int = GameLayers.HAZARD

@export_group("Efekt: Dezorientacja NPC (Amnezja)")
@export var apply_npc_amnesia: bool = true

@export_group("Dodatkowe Efekty (Opcjonalne)")
@export var apply_psychic_damage: bool = false
@export_range(1, 100, 1) var psychic_damage: int = 15
@export var apply_mind_decay_poison: bool = false
@export_range(1, 20, 1) var poison_damage_per_tick: int = 2
@export_range(1.0, 20.0, 1.0) var poison_duration: float = 5.0

func _init() -> void:
	ability_name = "Fala Psychozy"
	cooldown = 18.0
	min_range = 0.0
	max_range = 700.0

func execute(attacker: CharacterEntity, _target: CharacterEntity) -> void:
	if not is_instance_valid(attacker):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# 1. TWORZENIE ZJAWISKA WIZUALNEGO WOKÓŁ ATAKUJĄCEGO
	var wave_visual: PsychosisWaveVisual = PsychosisWaveVisual.new()
	wave_visual.radius = blast_radius
	wave_visual.color = aura_color
	wave_visual.cast_time = cast_time
	wave_visual.fade_time = explosion_fade_time
	wave_visual.target_node = attacker
	wave_visual.z_index = wave_z_index

	spawn_ability_node(attacker, wave_visual, attacker.global_position)

	# Animacja samego potwora (puchnięcie/pulsowanie w oparciu o bezpieczne base_scale!)
	var tween: Tween = attacker.create_tracked_tween()
	var orig_scale: Vector2 = attacker.base_scale
	tween.tween_property(attacker, "scale", orig_scale * visual_scale_pulse, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)
	tween.tween_property(attacker, "scale", orig_scale, cast_time * HALF_CAST_FACTOR).set_trans(Tween.TRANS_SINE)

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		if is_instance_valid(wave_visual):
			wave_visual.queue_free()
		return

	# 2. ŁADOWANIE
	await attacker.get_tree().create_timer(cast_time).timeout

	if is_instance_valid(attacker):
		attacker.reset_visual_scale()

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		if is_instance_valid(wave_visual):
			wave_visual.queue_free()
		return

	# 3. UDERZENIE FALI!
	if is_instance_valid(wave_visual):
		wave_visual.explode()

	var space_state: PhysicsDirectSpaceState2D = attacker.get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = blast_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, attacker.global_position)
	query.exclude = [attacker.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, MAX_PSYCHOSIS_HITS)

	var effects_to_apply: Array[Effect] = []

	if apply_psychic_damage: 
		var dmg_eff: DamageEffect = DamageEffect.new(psychic_damage)
		dmg_eff.effect_category = Effect.EffectCategory.MENTAL_PSYCHOSIS
		effects_to_apply.append(dmg_eff)
	if apply_freeze:
		var freeze: FreezeEffect = FreezeEffect.new(freeze_duration, false)
		freeze.effect_name = "Szok Neurotyczny"
		freeze.effect_category = Effect.EffectCategory.MENTAL_PSYCHOSIS
		effects_to_apply.append(freeze)
	if apply_stun: 
		effects_to_apply.append(StunEffect.new(stun_duration))
	if apply_slow: 
		var slow: SlowEffect = SlowEffect.new(slow_duration, slow_multiplier)
		slow.effect_name = "Otępienie Zmysłów"
		effects_to_apply.append(slow)
	if apply_mind_decay_poison:
		var poison: PoisonDebuffEffect = PoisonDebuffEffect.new()
		poison.effect_name = "Rozkład Umysłu"
		# NAPRAWA KRYTYCZNA: Używamy hp_per_tick zamiast nieistniejącego poison_damage_per_tick!
		poison.hp_per_tick = -abs(poison_damage_per_tick)
		poison.duration = poison_duration
		poison.effect_category = Effect.EffectCategory.MENTAL_PSYCHOSIS
		effects_to_apply.append(poison)

	var hit_player: bool = false

	for hit in hits:
		var col: Node2D = hit["collider"] as Node2D
		if not is_instance_valid(col):
			continue
		if not friendly_fire and is_ally_of(attacker, col):
			continue

		if col.has_method("receive_effect"):
			if col.is_in_group("Player"):
				hit_player = true

			for eff in effects_to_apply:
				var cloned_eff: Effect = eff.duplicate(true)
				cloned_eff.source_entity = attacker
				cloned_eff.source_position = attacker.global_position
				col.receive_effect(cloned_eff)

		# --- DEZORIENTACJA NPC ---
		if apply_npc_amnesia and col.has_node("AIController"):
			var target_ai: Node = col.get_node("AIController")
			if target_ai != null and target_ai.get("blackboard") != null:
				target_ai.blackboard.target = null
				target_ai.blackboard.has_last_known_position = false
				target_ai.blackboard.want_to_move = false
				if target_ai.get("state_machine") != null:
					target_ai.state_machine.change_state("Idle")

	# 4. WSTRZĄS KAMERY I MGŁA (Tylko jeśli Fala dotknęła Gracza)
	if hit_player:
		if apply_screen_shake:
			trigger_camera_shake(attacker, camera_trauma_amount)

		if apply_mental_fog:
			var fog: MentalFogVisual = MentalFogVisual.new()
			fog.duration = fog_duration
			fog.fog_color = fog_color
			fog.target_layer = fog_canvas_layer
			attacker.get_tree().current_scene.add_child(fog)

	if is_instance_valid(attacker) and combat_ctrl != null:
		combat_ctrl.is_casting_ability = false

# ==============================================================================
# KLASY WEWNĘTRZNE: Rysowanie fal psionicznych i mgły umysłu
# ==============================================================================
class PsychosisWaveVisual extends Node2D:
	var radius: float = 300.0
	var color: Color = Color.PURPLE
	var cast_time: float = 1.0
	var fade_time: float = 0.4
	var elapsed: float = 0.0
	var exploded: bool = false
	var post_explode_timer: float = 0.0
	var target_node: Node2D = null

	func _process(delta: float) -> void:
		if is_instance_valid(target_node):
			global_position = target_node.global_position

		if not exploded:
			elapsed += delta
			queue_redraw()
		else:
			post_explode_timer += delta
			queue_redraw()
			if post_explode_timer > fade_time:
				queue_free()

	func explode() -> void:
		exploded = true

	func _draw() -> void:
		if not exploded:
			var progress: float = clampf(elapsed / maxf(0.01, cast_time), 0.0, 1.0)
			var current_radius: float = radius * progress
			var pulse: float = (sin(elapsed * 15.0) + 1.0) / 2.0 
			var alpha: float = lerpf(0.1, 0.4, pulse)

			draw_circle(Vector2.ZERO, current_radius, Color(color.r, color.g, color.b, alpha))
			draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, color, 2.0)
		else:
			var progress: float = clampf(post_explode_timer / maxf(0.01, fade_time), 0.0, 1.0)
			var current_radius: float = radius + (progress * 80.0)
			var alpha: float = lerpf(0.8, 0.0, progress)

			draw_circle(Vector2.ZERO, current_radius, Color(color.r, color.g, color.b, alpha))
			draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, alpha), 5.0)

class MentalFogVisual extends CanvasLayer:
	var duration: float = 5.0
	var fog_color: Color = Color.BLACK
	var target_layer: int = 90

	func _ready() -> void:
		layer = target_layer
		var rect: ColorRect = ColorRect.new()
		rect.color = fog_color
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)

		var tween: Tween = create_tween()
		tween.tween_property(rect, "color:a", 1.0, 0.1)
		tween.tween_property(rect, "color:a", 0.8, 0.3)
		tween.tween_property(rect, "color:a", 0.95, 0.3)
		tween.tween_property(rect, "color:a", 0.0, maxf(0.1, duration - 0.7)).set_trans(Tween.TRANS_SINE)
		await tween.finished
		queue_free()
