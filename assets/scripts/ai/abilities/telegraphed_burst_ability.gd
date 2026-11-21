extends AIAbility
class_name TelegraphedBurstAbility
## Uniwersalny archetyp telegrafowanego wybuchu strefowego wokół rzucającego (SOLID - SRP / OCP / DRY).
## Stawia strefę ostrzegawczą (TelegraphedAOE) z efektami AttackData + on_hit_effects.
## Dodatkowe zachowania (np. leczenie/pacyfikacja sojuszników, wstrząs kamery, zaćmienie ekranu)
## podpina się modularnie w tablicy components w pliku .tres!

const DEFAULT_BURST_MAX_RANGE: float = 250.0

@export_category("Archetyp: Telegrafowany Wybuch Strefowy (TelegraphedBurstAbility)")

@export_group("Geometria i Czas Ładowania")
## Promień strefy wybuchu wokół rzucającego (w pikselach).
@export_range(40.0, 1200.0, 10.0) var blast_radius: float = 250.0
## Czas ładowania strefy ostrzegawczej przed detonacją (w sekundach).
@export_range(0.1, 6.0, 0.1) var cast_time: float = 1.5
## Czy strefa wybuchu ma ranić również sojuszników (friendly fire)?
@export var friendly_fire: bool = false
## Jeśli true (domyślnie), zabicie rzucającego w trakcie ładowania anuluje strefę wybuchu.
@export var cancel_on_caster_death: bool = true

@export_group("Wizualizacje i Warstwy Strefy")
## Warstwa renderowania (Z-Index) dla strefy zagrożenia TelegraphedAOE.
@export var aoe_z_index: int = GameLayers.HAZARD
## Kolor plamy ostrzegawczej (np. radioaktywna zieleń, ogień, lód).
@export var aoe_danger_color: Color = Color(0.2, 0.9, 0.1, 0.5)

func _init() -> void:
	ability_name = "Wybuch Strefowy"
	cooldown = 15.0
	min_range = 0.0
	max_range = DEFAULT_BURST_MAX_RANGE
	damage_category = Effect.EffectCategory.RADIATION

func execute(attacker: CharacterEntity, target: CharacterEntity) -> void:
	if not is_caster_active(attacker):
		return

	var attacker_ref: WeakRef = weakref(attacker)
	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	var combat_ctrl_ref: WeakRef = weakref(combat_ctrl) if combat_ctrl != null else null
	notify_components_cast_started(attacker, target)

	var enemy_effects: Array[Effect] = build_hit_effects(attacker)
	if not enemy_effects.is_empty():
		var aoe := TelegraphedAOE.new()
		aoe.setup(attacker.global_position, blast_radius, cast_time, enemy_effects, attacker)
		aoe.friendly_fire = friendly_fire
		aoe.cancel_on_caster_death = cancel_on_caster_death
		aoe.z_index = aoe_z_index
		aoe.z_as_relative = false
		aoe.danger_color = aoe_danger_color
		aoe.on_detonated_callback = func(origin_pos: Vector2, rad: float) -> void:
			notify_components_area_detonated(attacker_ref.get_ref(), origin_pos, rad)
		aoe.on_target_hit_callback = func(hit_target: Node2D, origin_pos: Vector2) -> void:
			notify_components_target_hit(attacker_ref.get_ref(), hit_target, origin_pos)
		spawn_ability_node(attacker, aoe, attacker.global_position)

	var scene_tree: SceneTree = attacker.get_tree()
	if scene_tree != null:
		await scene_tree.create_timer(cast_time).timeout

	_finish_cast(attacker_ref, combat_ctrl_ref)

## Bezpiecznie kończy rzucanie zdolności (WeakRef chroni przed błędem 'previously freed' po await).
func _finish_cast(attacker_ref: WeakRef, combat_ctrl_ref: WeakRef) -> void:
	if combat_ctrl_ref != null:
		var live_ctrl: Variant = combat_ctrl_ref.get_ref()
		if is_instance_valid(live_ctrl) and live_ctrl is AICombatController:
			(live_ctrl as AICombatController).is_casting_ability = false
	var live_attacker: Variant = attacker_ref.get_ref() if attacker_ref != null else null
	notify_components_cast_finished(live_attacker)
