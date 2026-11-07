extends AIAbility
class_name GammaBurstAbility

const DEFAULT_ALLY_HEAL_DURATION: float = 5.0
const DEFAULT_ALLY_HEAL_TICK_SEC: float = 1.0
const DEFAULT_ENEMY_STUN_SEC: float = 0.8

@export_category("Zdolność: Promieniowanie Gamma")
@export_group("Obrażenia i Zasięg (Wrogowie)")
@export var blast_radius: float = 250.0
@export var cast_time: float = 1.5
@export var radiation_damage: int = 25
## Czas lekkiego ogłuszenia nakładanego na wrogów (gracza) trafionych falą Gamma.
@export_range(0.0, 5.0, 0.1) var enemy_stun_duration: float = DEFAULT_ENEMY_STUN_SEC

@export_group("Wsparcie Sojuszników (Leczenie + Pacyfikacja)")
@export var heal_amount: int = 50
## Czas trwania regeneracji sojuszników oraz czas, przez który są niezdolni do ataku podczas leczenia.
@export_range(1.0, 15.0, 0.5) var ally_heal_duration: float = DEFAULT_ALLY_HEAL_DURATION
## Odstęp (w sekundach) pomiędzy kolejnymi tikami leczenia sojuszników.
@export_range(0.2, 5.0, 0.2) var ally_heal_tick_interval: float = DEFAULT_ALLY_HEAL_TICK_SEC

@export_group("Wizualizacje i Warstwy")
## Z-Index (warstwa rysowania) dla strefy zagrożenia.
@export var aoe_z_index: int = GameLayers.HAZARD
## Kolor plamy ostrzegawczej (TelegraphedAOE) - domyślnie radioaktywna zieleń.
@export var aoe_danger_color: Color = Color(0.2, 0.9, 0.1, 0.5)

func _init() -> void:
	ability_name = "Promieniowanie Gamma"
	cooldown = 15.0
	min_range = 0.0
	max_range = 250.0

func execute(attacker: CharacterEntity, _target: CharacterEntity) -> void:
	if not is_instance_valid(attacker):
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# 1. EFEKTY OFENSYWNE NA WROGÓW (Obrażenia + Trucizna Promieniowania + Lekki Stun)
	var aoe: TelegraphedAOE = TelegraphedAOE.new()
	var dmg_eff: DamageEffect = DamageEffect.new(radiation_damage)
	dmg_eff.effect_category = Effect.EffectCategory.RADIATION

	var poison: PoisonDebuffEffect = PoisonDebuffEffect.new()
	poison.effect_name = "Skazenie Gamma"
	poison.effect_category = Effect.EffectCategory.RADIATION

	var enemy_effects: Array[Effect] = [dmg_eff, poison]
	if enemy_stun_duration > 0.0:
		enemy_effects.append(StunEffect.new(enemy_stun_duration))

	aoe.setup(attacker.global_position, blast_radius, cast_time, enemy_effects, attacker)
	aoe.friendly_fire = false
	aoe.z_index = aoe_z_index
	aoe.z_as_relative = false
	aoe.danger_color = aoe_danger_color

	spawn_ability_node(attacker, aoe, attacker.global_position)

	# 2. WSPARCIE SOJUSZNIKÓW: Leczenie połączone z blokadą ataku na czas leczenia!
	var my_faction: FactionComponent = attacker.get_node_or_null("FactionComponent") as FactionComponent
	if my_faction != null and attacker.is_inside_tree():
		var ticks_count: int = maxi(1, int(round(ally_heal_duration / maxf(0.1, ally_heal_tick_interval))))
		@warning_ignore("integer_division")
		var hp_per_tick_val: int = maxi(1, int(heal_amount / ticks_count))

		for ally_node in attacker.get_tree().get_nodes_in_group("Character"):
			var ally: CharacterEntity = ally_node as CharacterEntity
			if ally == null or ally == attacker:
				continue

			var ally_rad: float = ally.combat_radius
			var edge_dist: float = maxf(0.0, attacker.global_position.distance_to(ally.global_position) - ally_rad)
			if edge_dist <= blast_radius and my_faction.get_disposition_toward(ally) == FactionComponent.Disposition.FRIENDLY:
				if ally.has_method("receive_effect"):
					var regen_eff: RegenerationBuffEffect = RegenerationBuffEffect.new(
						ally_heal_duration,
						ally_heal_tick_interval,
						hp_per_tick_val
					)
					ally.receive_effect(regen_eff)

					# W chwili leczenia sojusznicy są niezdolni do jakiegokolwiek ataku (czas stuna == czas leczenia)
					var pacify_stun: StunEffect = StunEffect.new(ally_heal_duration)
					pacify_stun.show_screen_feedback = false
					ally.receive_effect(pacify_stun)

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	await attacker.get_tree().create_timer(cast_time).timeout

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	if combat_ctrl != null:
		combat_ctrl.is_casting_ability = false
