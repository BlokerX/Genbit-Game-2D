extends Control

@onready var main_scene = self.get_parent()
@onready var button_start = $"Menu Panel/Menu Options/Menu Buttons/PlayButton"
@onready var button_credits = $"Menu Panel/Menu Options/Menu Buttons/CreditsButton"
@onready var canvaslayer_menus = $CanvasLayer
@onready var ambience = $Ambience

func _ready() -> void:
	button_start.pressed.connect(button_start_pressed)
	
	button_credits.main_scene_node = canvaslayer_menus
	ambience.play()

func button_start_pressed() -> void:
	main_scene.start_game(self)
