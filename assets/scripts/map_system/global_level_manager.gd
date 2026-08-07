extends Node

## ID wejścia, w którym gracz ma się pojawić po załadowaniu nowej mapy
var target_entrance_id: String = ""

## Funkcja wywoływana przez schody/portale
func change_level(scene_to_load: PackedScene, entrance_id: String) -> void:
	target_entrance_id = entrance_id
	
	# Zatrzymujemy fizykę gracza (szukamy go bezpiecznie)
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Wywołujemy ściemnienie z Twojego TransitionManagera
	TransitionManager.fade_to_black(0.3)
	await TransitionManager.on_fade_out_finished
	
	# Podmieniamy główną scenę na nową mapę (np. Poziom 2)
	get_tree().change_scene_to_packed(scene_to_load)
	
	# UWAGA: Rozjaśnieniem zajmie się już skrypt nowej mapy po jej załadowaniu!
