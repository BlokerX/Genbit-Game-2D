extends "res://assets/scripts/entities/player/player_stats/stats_universal.gd"

@export var health_points_bar : ProgressBar

func _ready():
	pass

func _physics_process(delta):
	pass

func _process(delta):
	#region show in GUI
	health_points_bar.value = health
	#endregion
	
