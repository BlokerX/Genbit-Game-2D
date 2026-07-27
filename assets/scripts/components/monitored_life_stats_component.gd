extends LifeStatsComponent

class_name MonitoredLifeStatsComponent

signal health_updated(current_health: int, maximum_health: int)
signal max_health_changed(new_max_health: int)

# D_E_B_U_G
func monitor() -> void :
	#print("Monitor zdrowia gracza: ", health, " / ", max_health)
	return

#override
func boost_max_health(boost : int) -> void :
	super.boost_max_health(boost)
	emit_max_health_change()
	emit_health_update() # Aktualizujemy też zwykłe HP, bo zmieniły się proporcje

#override
func reduce_max_health(reduction : int) -> void :
	super.reduce_max_health(reduction)
	emit_max_health_change()
	emit_health_update()

#override
func reset_stats() -> void :
	super.reset_stats()
	emit_max_health_change()
	emit_health_update()

# Ta funkcja teraz tylko "ogłasza" zmianę zdrowia, zamiast fizycznie zmieniać pasek
func emit_health_update() -> void :
	health_updated.emit(health, max_health)
	monitor()

# Ta funkcja ogłasza zmianę maksymalnego zdrowia
func emit_max_health_change() -> void :
	max_health_changed.emit(max_health)
