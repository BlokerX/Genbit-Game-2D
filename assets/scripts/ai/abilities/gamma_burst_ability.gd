extends AIAbility
class_name GammaBurstAbility
## Uniwersalny archetyp impulsu strefowego o podwójnym działaniu (SOLID - OCP / DRY).
## Nakłada efekty ofensywne (AttackData + on_hit_effects) na wrogów w promieniu strefy ostrzegawczej (TelegraphedAOE)
## oraz niezależną, otwartą listę efektów wsparcia/kontroli (ally_effects) na sojuszników w zasięgu.

const DEFAULT_BURST_MAX_RANGE: float = 250.0
const ALLY_SHOCKWAVE_DURATION_SEC: float = 0.42
const ALLY_SHOCKWAVE_FILL_ALPHA: float = 0.14

@export_category("Archetyp: Impuls Strefowy (Wrogowie + Sojusznicy)")

@export_group("Geometria i Czas Ładowania")
## Promień wybuchu obejmujący zarówno wrogów, jak i sojuszników (w pikselach).
@export_range(40.0, 1200.0, 10.0) var blast_radius: float = 250.0
## Czas ładowania strefy ostrzegawczej przed detonacją (w sekundach).
@export_range(0.1, 6.0, 0.1) var cast_time: float = 1.5
## Czy strefa ofensywna ma ranić również sojuszników (friendly fire)?
@export var friendly_fire: bool = false

@export_group("Efekty dla Sojuszników (Konfiguracja w .tres)")
## Otwarta lista efektów nakładanych na sojuszników w zasięgu blast_radius
## (np. RegenerationBuffEffect + StunEffect pacyfikujący na czas leczenia, albo ArmorBuff + Speed).
@export var ally_effects: Array[Effect] = []
## Jeśli false (domyślnie), sojusznicy otrzymują ally_effects od razu w chwili rozpoczęcia ładowania.
## Jeśli true, sojusznicy otrzymują ally_effects dopiero w momencie detonacji strefy.
@export var apply_ally_effects_on_detonation: bool = false
## Czy sam rzucający ma również otrzymać efekty z listy ally_effects?
@export var include_caster_in_ally_effects: bool = false

@export_group("Wizualizacje, Warstwy i Kamera")
## Warstwa renderowania (Z-Index) dla strefy zagrożenia TelegraphedAOE.
@export var aoe_z_index: int = GameLayers.HAZARD
## Kolor plamy ostrzegawczej dla wrogów (domyślnie radioaktywna zieleń).
@export var aoe_danger_color: Color = Color(0.2, 0.9, 0.1, 0.5)
## Kolor fali wizualnej generowanej przy nakładaniu efektów wsparcia na sojuszników.
@export var ally_pulse_color: Color = Color(0.32, 0.98, 0.55, 0.85)
## Siła wstrząsu kamery w chwili detonacji impulsu (0.0 wyłącza wstrząs).
@export_range(0.0, 1.5, 0.05) var camera_trauma_amount: float = 0.35

func _init() -> void:
	ability_name = "Promieniowanie Gamma"
	cooldown = 15.0
	min_range = 0.0
	max_range = DEFAULT_BURST_MAX_RANGE
	damage_category = Effect.EffectCategory.RADIATION

func execute(attacker: CharacterEntity, _target: CharacterEntity) -> void:
	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)

	# 1. Strefa ostrzegawcza z efektami ofensywnymi zbudowanymi z jednolitego kontraktu AIAbility
	var enemy_effects: Array[Effect] = build_hit_effects(attacker)
	if not enemy_effects.is_empty():
		var aoe := TelegraphedAOE.new()
		aoe.setup(attacker.global_position, blast_radius, cast_time, enemy_effects, attacker)
		aoe.friendly_fire = friendly_fire
		aoe.z_index = aoe_z_index
		aoe.z_as_relative = false
		aoe.danger_color = aoe_danger_color
		spawn_ability_node(attacker, aoe, attacker.global_position)

	# 2. Natychmiastowe wsparcie sojuszników (jeśli nie odroczono do detonacji)
	if not apply_ally_effects_on_detonation:
		_apply_effects_to_allies_in_radius(attacker)

	await attacker.get_tree().create_timer(cast_time).timeout

	if not is_instance_valid(attacker) or not attacker.is_inside_tree():
		if is_instance_valid(combat_ctrl):
			combat_ctrl.is_casting_ability = false
		return

	if not attacker.is_dead:
		if apply_ally_effects_on_detonation:
			_apply_effects_to_allies_in_radius(attacker)
		if camera_trauma_amount > 0.0:
			trigger_camera_shake(attacker, camera_trauma_amount)

	if is_instance_valid(combat_ctrl):
		combat_ctrl.is_casting_ability = false

## Wyszukuje sojuszników w promieniu blast_radius (edge-to-edge) i nakłada na nich skonfigurowaną listę ally_effects.
func _apply_effects_to_allies_in_radius(attacker: CharacterEntity) -> void:
	if ally_effects.is_empty() or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return

	var applied_to_anyone: bool = false
	for char_node in attacker.get_tree().get_nodes_in_group("Character"):
		var ally: CharacterEntity = char_node as CharacterEntity
		if ally == null or ally.is_dead:
			continue
		if not can_affect_target(attacker, ally, true, false, include_caster_in_ally_effects):
			continue

		var edge_dist: float = get_edge_distance(attacker, ally)
		if edge_dist <= blast_radius:
			if apply_effects_to_target(attacker, ally, ally_effects, attacker.global_position):
				applied_to_anyone = true

	if applied_to_anyone:
		CombatVFXHelper.spawn_shockwave(
			attacker,
			attacker.global_position,
			blast_radius,
			ally_pulse_color,
			ALLY_SHOCKWAVE_DURATION_SEC,
			GameLayers.FX,
			ALLY_SHOCKWAVE_FILL_ALPHA
		)
