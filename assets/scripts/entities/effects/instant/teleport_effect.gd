extends Effect
class_name TeleportEffect

## Zasięg teleportacji. Wartość 0 oznacza BRAK LIMITU (dokładnie w miejsce kursora myszy).
@export var max_teleport_distance: float = 0.0

func _init(_dist: float = 0.0):
	effect_name = "Blink"
	effect_color = Color.AQUA
	max_teleport_distance = _dist

func apply_effect(target: Node2D) -> bool:
	var target_pos = target.global_position
	
	if target.has_node("AimController"):
		# Teleportacja centralnie w kursor myszy
		if target.get("is_using_mouse") == true:
			target_pos = target.get_global_mouse_position()
		# Fallback na celownik z pada
		else:
			var aim_ctrl = target.get_node("AimController")
			if aim_ctrl.get("aim_scanner"):
				target_pos = aim_ctrl.aim_scanner.global_position
	
	# Ograniczenie zasięgu DZIAŁA TYLKO WSTEDY, gdy ustawisz max_teleport_distance większe od 0.
	# Jeśli zostawisz 0, gracz skacze zawsze dokładnie na kursor.
	if max_teleport_distance > 0.0 and target.global_position.distance_to(target_pos) > max_teleport_distance:
		var dir = target.global_position.direction_to(target_pos).normalized()
		target_pos = target.global_position + (dir * max_teleport_distance)

	# Błyskawiczna teleportacja wymuszająca nową pozycję (przenika przez wszystko)
	target.global_position = target_pos
	
	print(target.name, " przeteleportował się!")
	return true
