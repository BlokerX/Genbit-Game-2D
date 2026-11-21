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

	var combat_ctrl: AICombatController = set_casting_state(attacker, true)
	notify_components_cast_started(attacker, target)

	var enemy_effects: Array[Effect] = build_hit_effects(attacker)
	if not enemy_effects.is_empty():
		var aoe := TelegraphedAOE.new()
		aoe.setup(attacker.global_position, blast_radius, cast_time, enemy_effects, attacker)
		aoe.friendly_fire = friendly_fire
		aoe.z_index = aoe_z_index
		aoe.z_as_relative = false
		aoe.danger_color = aoe_danger_color
		aoe.on_detonated_callback = func(origin_pos: Vector2, rad: float) -> void:
			notify_components_area_detonated(attacker, origin_pos, rad)
		aoe.on_target_hit_callback = func(hit_target: Node2D, origin_pos: Vector2) -> void:
			notify_components_target_hit(attacker, hit_target, origin_pos)
		spawn_ability_node(attacker, aoe, attacker.global_position)

	await attacker.get_tree().create_timer(cast_time).timeout

	_finish_cast(attacker, combat_ctrl)

## Bezpiecznie kończy rzucanie zdolności (parametry Variant chronią przed błędem 'previously freed' po await).
func _finish_cast(attacker: Variant, combat_ctrl: Variant) -> void:
	if is_instance_valid(combat_ctrl) and combat_ctrl is AICombatController:
		(combat_ctrl as AICombatController).is_casting_ability = false
	notify_components_cast_finished(attacker)
