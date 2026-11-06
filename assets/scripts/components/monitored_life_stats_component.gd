extends LifeStatsComponent
class_name MonitoredLifeStatsComponent

signal health_updated(current_health: int, maximum_health: int)
signal max_health_changed(new_max_health: int)

func _init() -> void:
	# NAPRAWA KRYTYCZNA (Odblokowanie Faz Bossa w AIPhaseController):
	# Każda zmiana zdrowia (take_damage, heal, kill) automatycznie zasila sygnał health_updated!
	if not health_changed.is_connected(_on_internal_health_changed):
		health_changed.connect(_on_internal_health_changed)

func _on_internal_health_changed(_new_health: int, _max_health: int) -> void:
	emit_health_update()

func monitor() -> void :
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
