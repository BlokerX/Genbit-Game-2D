extends "res://assets/scripts/entities/stats/stats_res.gd"

class_name MonitoredStatsComponent

var health_points_bar : ProgressBar
var health_points_label : Label

# D_E_B_U_G
func monitor() -> void :
	#print("Monitor zdrowia gracza: ", health, " / ", max_health)
	return

func update_helath_points_bar() -> void :
	# Show HP in GUI
	# percents:
	# health_points_bar.value = health * 100 / max_health
	# points:
	health_points_bar.value = health
	health_points_label.text = str(health) + " / " + str(max_health)
	monitor()

func change_health_points_bar_max_value() :
	health_points_bar.max_value = max_health

#override
func boost_max_health(boost : int) -> void :
	super.boost_max_health(boost)
	change_health_points_bar_max_value()

#override
func reduce_max_health(reduction : int) -> void :
	super.reduce_max_health(reduction)
	change_health_points_bar_max_value()

func reset_stats() :
	super.reset_stats()
	change_health_points_bar_max_value()
