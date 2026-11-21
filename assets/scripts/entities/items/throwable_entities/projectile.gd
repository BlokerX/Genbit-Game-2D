extends Area2D
class_name Projectile
## Pocisk wystrzeliwany z broni dystansowej (RangedWeaponComponent).
## Obsługuje detekcję RayCast oraz powierzchniową, penetrację sojuszników, kolizje z osłonami (PlacedObject),
## proceduralną smugę lotu oraz iskry impaktu dobierane automatycznie do żywiołu pocisku (SOLID - SRP / DRY).

#region Stałe Fizyczne i Wizualne (Brak magicznych liczb)
const MAX_ALLY_PENETRATIONS: int = 5
const MAX_RAY_QUERY_STEPS: int = 16
const SPRITE_ROTATION_OFFSET_RAD: float = 0.0

const DEFAULT_PROJECTILE_VFX_COLOR := Color(1.0, 0.86, 0.42, 0.95)
const IMPACT_SPARK_COUNT: int = 6
const IMPACT_SPARK_RADIUS_PX: float = 18.0
const IMPACT_SPARK_DURATION_SEC: float = 0.16
#endregion

@export var speed: float = 600.0
@export var lifetime: float = 4.0
@export var friendly_fire: bool = false

@export_group("Kolizje z Obiektami i Osłonami")
## Maska warstw fizyki dla ścian i postawionych obiektów (np. skrzyń), łączona bitowo z collision_mask pocisku.
@export_flags_2d_physics var obstacles_collision_mask: int = 1
## Czy pocisk ma wykrywać postawione obiekty (PlacedObject) również przez ich komponent interakcji (Area2D)?
## Gwarantuje trafianie w skrzynie niezależnie od ustawionej warstwy StaticBody2D.
@export var detect_placed_object_areas: bool = true

@export_group("Efekty Wizualne (VFX)")
## Czy rysować lekką, dwuwarstwową smugę energetyczną za lecącym pociskiem?
@export var enable_trail: bool = true
## Maksymalna długość smugi ciągnącej się za pociskiem (w pikselach).
@export_range(6.0, 80.0, 2.0) var trail_length_px: float = 20.0
## Grubość zewnętrznej poświaty smugi u podstawy pocisku (w pikselach).
@export_range(1.0, 10.0, 0.2) var trail_width_px: float = 2.5
## Czy w punkcie trafienia (wróg, skrzynia, ściana) generować rozbłysk iskier (CombatVFXHelper)?
@export var spawn_impact_sparks: bool = true
## Opcjonalny własny kolor smugi i iskier. Gdy przezroczysty (alpha == 0), kolor dobierany jest automatycznie z efektów pocisku.
@export var override_vfx_color: Color = Color(0.0, 0.0, 0.0, 0.0)

var direction: Vector2 = Vector2.ZERO
var effects_to_apply: Array[Effect] = []

var _time_alive: float = 0.0
var _traveled_distance: float = 0.0
var _trail_settled: bool = false
var _resolved_vfx_color: Color = DEFAULT_PROJECTILE_VFX_COLOR
var shooter: Node2D = null
var _shooter_faction_name: StringName = &""
var _has_hit: bool = false

func _ready() -> void:
	add_to_group("Hazard")
	collision_mask |= obstacles_collision_mask

	body_entered.connect(_on_body_entered)
	if detect_placed_object_areas and not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	# Zapamiętujemy frakcję strzelca na wypadek jego śmierci przed dolotem pocisku
	if is_instance_valid(shooter):
		var my_faction: FactionComponent = shooter.get_node_or_null("FactionComponent") as FactionComponent
		if my_faction != null:
			_shooter_faction_name = my_faction.faction_name

	# Zachowujemy pionowy offset rotacji tekstury pocisku nadany przez RangedWeaponComponent
	rotation = direction.angle() + SPRITE_ROTATION_OFFSET_RAD
	_resolved_vfx_color = _resolve_vfx_color()

func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	# Oczyszczenie wskaźnika strzelca, jeśli zginął w trakcie lotu pocisku (chroni przed błędem 'previously freed')
	if not is_instance_valid(shooter):
		shooter = null

	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	var remaining_dist: float = speed * delta
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * remaining_dist
	)
	query.collision_mask = collision_mask | obstacles_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = detect_placed_object_areas

	var excluded_rids: Array[RID] = [get_rid()]
	if shooter != null and shooter is CollisionObject2D:
		excluded_rids.append((shooter as CollisionObject2D).get_rid())
	query.exclude = excluded_rids

	var hit_valid_target: bool = false
	var ally_penetrations_left: int = MAX_ALLY_PENETRATIONS
	var steps_left: int = MAX_RAY_QUERY_STEPS

	# Pętla penetrująca: ignoruje sojuszników, nieistotne Area2D oraz obiekty z włączoną niewidzialnością na pociski
	while ally_penetrations_left > 0 and steps_left > 0:
		steps_left -= 1
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break

		var raw_collider: Object = result["collider"]
		var hit_pos: Vector2 = result["position"]
		var resolved_target: Node2D = _resolve_collision_target(raw_collider)

		# 1. Trafiono pomocnicze Area2D niebędące celem bojowym ani obiektem PlacedObject (np. czujnik podnoszenia itemu)
		if resolved_target == null:
			if raw_collider is CollisionObject2D:
				excluded_rids.append((raw_collider as CollisionObject2D).get_rid())
				query.exclude = excluded_rids
			continue

		# 2. Trafiono obiekt PlacedObject, który ma włączoną opcję niewidzialności na pociski (invisible_to_projectiles)
		if resolved_target.has_method("should_block_projectile") and resolved_target.call("should_block_projectile", self) != true:
			if raw_collider is CollisionObject2D:
				excluded_rids.append((raw_collider as CollisionObject2D).get_rid())
			if resolved_target is CollisionObject2D:
				excluded_rids.append((resolved_target as CollisionObject2D).get_rid())
			query.exclude = excluded_rids
			query.from = hit_pos
			continue

		# 3. Trafiono samego strzelca lub sojusznika (gdy friendly_fire == false)
		if (shooter != null and resolved_target == shooter) or (not friendly_fire and _is_ally(resolved_target)):
			if raw_collider is CollisionObject2D:
				excluded_rids.append((raw_collider as CollisionObject2D).get_rid())
			if resolved_target is CollisionObject2D:
				excluded_rids.append((resolved_target as CollisionObject2D).get_rid())
			query.exclude = excluded_rids
			query.from = hit_pos
			ally_penetrations_left -= 1
			continue

		# 4. Trafiono prawowity cel (Wróg / Ściana / Skrzynia lub Osłona)
		global_position = hit_pos
		_apply_hit_and_destroy(resolved_target)
		hit_valid_target = true
		break

	if not hit_valid_target:
		global_position += direction * remaining_dist
		_traveled_distance += remaining_dist
		if enable_trail and not _trail_settled:
			queue_redraw()
			if _traveled_distance >= trail_length_px:
				_trail_settled = true

func _draw() -> void:
	if not enable_trail or direction == Vector2.ZERO:
		return
	var current_len: float = minf(trail_length_px, _traveled_distance)
	CombatVFXHelper.draw_motion_trail(self, direction, global_rotation, current_len, trail_width_px, _resolved_vfx_color)

## Dobiera kolor smugi i iskier na podstawie własnego nadpisania lub priorytetu efektów pocisku (DRY / OCP).
func _resolve_vfx_color() -> Color:
	if override_vfx_color.a > 0.0:
		return override_vfx_color
	return CombatVFXHelper.resolve_color_from_effects(effects_to_apply, DEFAULT_PROJECTILE_VFX_COLOR)

## Rozwiązuje trafiony kolider do właściwego węzła docelowego (obsługuje również InteractableComponent na skrzyniach).
func _resolve_collision_target(collider: Object) -> Node2D:
	if not is_instance_valid(collider) or not (collider is Node):
		return null

	if collider is PlacedObject or collider is CharacterEntity:
		return collider as Node2D

	if collider is Area2D:
		var parent: Node = (collider as Node).get_parent()
		if parent is PlacedObject:
			return parent as Node2D
		return null

	return collider as Node2D

func _on_body_entered(body: Node2D) -> void:
	var resolved: Node2D = _resolve_collision_target(body)
	if resolved != null:
		_apply_hit_and_destroy(resolved)

func _on_area_entered(area: Area2D) -> void:
	if not detect_placed_object_areas:
		return
	var resolved: Node2D = _resolve_collision_target(area)
	if resolved is PlacedObject:
		_apply_hit_and_destroy(resolved)

func _apply_hit_and_destroy(target_node: Node2D) -> void:
	if not is_instance_valid(shooter):
		shooter = null
	if _has_hit or not is_instance_valid(target_node) or (shooter != null and target_node == shooter):
		return
	if not friendly_fire and _is_ally(target_node):
		return
	if target_node.has_method("should_block_projectile") and target_node.call("should_block_projectile", self) != true:
		return

	_has_hit = true
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if area_entered.is_connected(_on_area_entered):
		area_entered.disconnect(_on_area_entered)

	set_deferred("monitoring", false)

	if spawn_impact_sparks:
		CombatVFXHelper.spawn_impact_sparks(
			self,
			global_position,
			-direction,
			_resolved_vfx_color,
			IMPACT_SPARK_COUNT,
			IMPACT_SPARK_RADIUS_PX,
			IMPACT_SPARK_DURATION_SEC
		)

	if target_node.has_method("receive_effect"):
		for effect in effects_to_apply:
			if effect != null:
				var cloned_eff: Effect = effect.duplicate(true) as Effect
				cloned_eff.source_position = self.global_position
				cloned_eff.source_entity = shooter if is_instance_valid(shooter) else null
				cloned_eff.set_meta("from_projectile", true)
				target_node.receive_effect(cloned_eff)

	queue_free()

## Sprawdza FactionComponent by zweryfikować czy cele są po tej samej stronie (DRY).
func _is_ally(body: Node2D) -> bool:
	var valid_shooter: Node2D = shooter if is_instance_valid(shooter) else null
	return FactionComponent.is_ally_of(valid_shooter, body, _shooter_faction_name)
