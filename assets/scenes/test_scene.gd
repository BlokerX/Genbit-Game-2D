extends Node2D

func _ready() -> void:
	pass

# Zostaw to całkowicie puste lub usuń logikę Input z _physics_process
func _physics_process(_delta: float) -> void:
	pass

# Tę funkcję możesz też usunąć, bo PauseMenu odwołuje się teraz
# bezpośrednio do main_node.to_main_menu() !
