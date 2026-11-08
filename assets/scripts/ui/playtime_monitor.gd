extends Label
## Monitor czasu rozgrywki wyświetlający czas spędzony w aktywnej sesji gry (w formacie HH:MM:SS).

const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60
const SECONDS_PER_HOUR: int = 3600

## Czy zawsze wyświetlać człon godzinowy (00:mm:ss), nawet przed upływem pierwszej godziny gry?
@export var always_show_hours: bool = true

var playtime: float = 0.0

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	playtime += delta

	var total_seconds: int = int(playtime)
	@warning_ignore("integer_division")
	var hours: int = int(total_seconds / SECONDS_PER_HOUR)
	@warning_ignore("integer_division")
	var minutes: int = int((total_seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
	var seconds: int = total_seconds % SECONDS_PER_MINUTE

	if always_show_hours or hours > 0:
		text = "%02d:%02d:%02d" % [hours, minutes, seconds]
	else:
		text = "%02d:%02d" % [minutes, seconds]
