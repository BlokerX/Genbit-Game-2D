extends Label

var playtime: float = 0.0

func _process(delta: float) -> void:
	playtime += delta
	var minutes = int(playtime) / 60
	var seconds = int(playtime) % 60
	text = "%02d:%02d" % [minutes, seconds]
