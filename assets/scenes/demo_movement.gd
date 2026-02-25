extends Node2D


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Game_Pause"):
		back_to_main_menu()
	

func back_to_main_menu() -> void:
	get_parent().to_main_menu()
	self.queue_free()
