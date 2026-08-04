extends Node
class_name AttackComponent

# Przeniesione z gracza:
## Scena pocisku dla broni dystansowej
@export var projectile_scene: PackedScene

## Sygnał wywoływany, gdy komponent chce zespawnować pocisk (przechwyci go gracz)
signal spawn_projectile_requested(projectile_node: Node2D, spawn_position: Vector2)

# Główna funkcja wywoływana przez gracza (lub w przyszłości przez przeciwnika!)
func execute_attack(
	shooter: CharacterEntity, 
	target: Node2D, 
	weapon_data: ItemData, 
	stats_script: Resource, 
	distance_to_target: float, 
	max_distance: float,
	has_line_of_sight: bool
) -> bool:
	
	# Weryfikacja dystansu
	if distance_to_target > max_distance:
		print("Pudło! Wróg poza zasięgiem broni. (Dystans: ", distance_to_target, " / Max: ", max_distance, ")")
		return false

	# Rozdzielenie logiki w zależności od typu broni
	if weapon_data is ItemWeapon:
		if weapon_data is ItemDistanceWeapon:
			return _handle_ranged_attack(shooter, target, weapon_data, stats_script)
		else:
			return _handle_melee_attack(shooter, target, stats_script, has_line_of_sight)
	elif weapon_data == null:
		return _handle_unarmed_attack(shooter, target, stats_script, has_line_of_sight)
		
	return false

func _handle_ranged_attack(shooter: CharacterEntity, target: Node2D, weapon_data: ItemDistanceWeapon, stats_script: Resource) -> bool:
	if projectile_scene == null:
		push_error("BŁĄD: AttackComponent próbuje strzelać, ale nie przypisano 'projectile_scene'!")
		return false
		
	print("Strzał z broni dystansowej!")
	
	var generated_effects = []
	if stats_script and stats_script.has_method("get_all_attack_effects"):
		generated_effects = stats_script.get_all_attack_effects()
	
	var new_projectile = projectile_scene.instantiate()
	new_projectile.shooter = shooter
	new_projectile.global_position = shooter.global_position
	
	# Obliczenie wektora kierunku
	var shoot_dir = shooter.global_position.direction_to(target.global_position)
	new_projectile.direction = shoot_dir
	
	# --- NOWOŚĆ: Korekta rotacji pocisku ---
	# shoot_dir.angle() oblicza kąt do celu, a PI / 2.0 (90 stopni) koryguje fakt,
	# że oryginalna grafika pocisku patrzy domyślnie w górę zamiast w prawo.
	new_projectile.rotation = shoot_dir.angle() + (PI / 2.0)
	
	if "effects_to_apply" in new_projectile:
		new_projectile.effects_to_apply = generated_effects
		
	# Przypisywanie statystyk bezpośrednio z definicji broni
	if "speed" in new_projectile:
		new_projectile.speed = weapon_data.projectile_speed
	elif "projectile_speed" in new_projectile:
		new_projectile.projectile_speed = weapon_data.projectile_speed

	if "lifetime" in new_projectile:
		new_projectile.lifetime = weapon_data.projectile_lifetime

	var sprite = new_projectile.get_node_or_null("Sprite2D")
	if sprite != null and weapon_data.projectile_texture != null:
		sprite.texture = weapon_data.projectile_texture
		
	# Zgłaszamy światu, że pocisk jest gotowy do lotu
	spawn_projectile_requested.emit(new_projectile, shooter.global_position)
	return true

func _handle_melee_attack(shooter: CharacterEntity, target: Node2D, stats_script: Resource, has_line_of_sight: bool) -> bool:
	if not has_line_of_sight:
		print("Atak zablokowany przez ścianę!")
		return false
		
	print("Cios z broni białej!")
	if stats_script and stats_script.has_method("execute_attack_on_target"):
		stats_script.execute_attack_on_target(target)
	return true

func _handle_unarmed_attack(shooter: CharacterEntity, target: Node2D, stats_script: Resource, has_line_of_sight: bool) -> bool:
	if not has_line_of_sight:
		print("Atak zablokowany przez ścianę!")
		return false
		
	print("Gracz trafia z pięści!")
	if stats_script and stats_script.has_method("execute_attack_on_target"):
		stats_script.execute_attack_on_target(target)
	return true
