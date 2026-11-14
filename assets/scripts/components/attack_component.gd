extends Node
class_name AttackComponent
## Komponent wykonujący ataki postaci (zarówno bronią z komponentami, jak i gołą pięścią).

signal spawn_projectile_requested(projectile_node: Node2D, spawn_position: Vector2)

const DEFAULT_COMBAT_RADIUS_PX: float = 20.0

func execute_attack(
	shooter: CharacterEntity,
	target: Node2D,
	weapon_instance: ItemInstance,
	_inventory: Variant,
	stats_script: InteractionAndAttackStatsComponent,
	has_line_of_sight: bool
) -> bool:
	if not has_line_of_sight or shooter == null or stats_script == null:
		return false

	# 1. SPRAWDZENIE CZY TRZYMANY PRZEDMIOT POSIADA KOMPONENT BOJOWY / WYKONAWCZY (SOLID - OCP)
	var executable_comp: ItemComponent = _find_executable_attack_component(weapon_instance)

	# Jeśli brak broni (lub trzymamy np. zasób drewna) -> uderzamy gołą pięścią!
	if executable_comp == null:
		if target == null:
			return false
		var unarmed_dist: float = _get_edge_distance(shooter, target)
		if unarmed_dist > stats_script.get_total_range():
			return false
		stats_script.execute_attack_on_target(shooter, target)
		return true

	# 2. WYKONANIE ATAKU KOMPONENTEM (Z WERYFIKACJĄ ZASIĘGU WRĘCZ I WARUNKÓW ITEM_CONDITION!)
	if executable_comp.requires_melee_range_check():
		if target == null:
			return false
		var melee_dist: float = _get_edge_distance(shooter, target)
		if melee_dist > stats_script.get_total_range():
			return false

	return executable_comp.try_execute(shooter, target, weapon_instance)

## Wyszukuje pierwszy komponent zdolny do wykonania ataku na przedmiocie.
func _find_executable_attack_component(weapon_instance: ItemInstance) -> ItemComponent:
	if weapon_instance == null or weapon_instance.data == null or weapon_instance.data.components == null:
		return null
	for comp in weapon_instance.data.components:
		if comp != null and comp.is_executable_attack_component():
			return comp
	return null

## Oblicza dystans od krawędzi do krawędzi (Edge-to-Edge) pomiędzy strzelcem a celem (DRY - uwzględnia skalę bossów).
func _get_edge_distance(shooter: Variant, target: Variant) -> float:
	return CharacterEntity.get_edge_distance_between(shooter, target)
