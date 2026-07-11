extends Control

@onready var button_start = $"MenuPanel/MenuOptions/MenuButtons/PlayButton"
@onready var button_credits = $"MenuPanel/MenuOptions/MenuButtons/CreditsButton"
@onready var canvaslayer_menus = $CanvasLayer
@onready var ambience = $Ambience

func _ready() -> void:
	button_start.pressed.connect(button_start_pressed)
	button_credits.main_scene_node = canvaslayer_menus
	ambience.play()
	button_start.grab_focus()

func button_start_pressed() -> void:
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("start_game"):
		main_node.start_game()
	else:
		push_error("Błąd: Nie znaleziono węzła głównego (Main) na drzewie!")

func retake_focus() -> void:
	button_start.grab_focus()
