extends Effect
class_name TeleportEffect

const DEFAULT_WALL_STOP_MARGIN_PX: float = 24.0
const DEFAULT_OBSTACLES_MASK: int = 1

## Zasięg teleportacji. Wartość 0 oznacza BRAK LIMITU (dokładnie w miejsce kursora myszy).
@export var max_teleport_distance: float = 0.0
## Czy teleportacja ma zatrzymywać się przed ścianami (chroni przed wypadnięciem poza mapę)?
@export var stop_at_walls: bool = true
## Maska fizyki dla ścian i przeszkód terenowych.
@export_flags_2d_physics var obstacles_mask: int = DEFAULT_OBSTACLES_MASK

func _init(_dist: float = 0.0):
	effect_name = "Blink"
	effect_color = Color.AQUA
	effect_category = EffectCategory.UTILITY
	max_teleport_distance = _dist

func apply_effect(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false

	var target_pos: Vector2 = target.global_position

	if target.has_node("AimController"):
		if target.get("is_using_mouse") == true:
			target_pos = target.get_global_mouse_position()
		else:
			var aim_ctrl = target.get_node("AimController")
			if aim_ctrl.get("aim_scanner"):
				target_pos = aim_ctrl.aim_scanner.global_position

	if max_teleport_distance > 0.0 and target.global_position.distance_to(target_pos) > max_teleport_distance:
		var dir: Vector2 = target.global_position.direction_to(target_pos).normalized()
		target_pos = target.global_position + (dir * max_teleport_distance)

	# ZABEZPIECZENIE PRZED WYPADNIĘCIEM POZA MAPĘ:
	if stop_at_walls and target.is_inside_tree():
		var body_margin: float = float(target.get("combat_radius")) if "combat_radius" in target else DEFAULT_WALL_STOP_MARGIN_PX
		target_pos = ItemPickup.calculate_safe_spawn_position(
			target.global_position,
			target_pos,
			target,
			obstacles_mask,
			body_margin
		)

	target.global_position = target_pos
	print(target.name, " przeteleportował się!")
	return true
