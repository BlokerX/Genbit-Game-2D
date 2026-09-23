extends Label

@export var player : PlayerCharacter

func _process(_delta: float) -> void:
	if player:
		# Pobieramy globalny rozmiar chunka z ustawień
		var chunk_size = GlobalSettings.chunk_base_size
		
		# Obliczamy koordynaty chunka (zaokrąglając w dół, dokładnie tak samo jak robi to streamer)
		var chunk_x = int(floor(player.global_position.x / chunk_size))
		var chunk_y = int(floor(player.global_position.y / chunk_size))
		
		# --- NOWE PARAMETRY ---
		var fps = Engine.get_frames_per_second()
		
		# Pamięć RAM i VRAM (w megabajtach)
		var ram_usage = OS.get_static_memory_usage() / 1048576.0
		var vram_usage = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		
		# Wyświetlamy pozycję gracza, koordynaty chunka oraz nowe statystyki
		text = "FPS: %d\nRAM: %.1f MB\nVRAM: %.1f MB\nX: %d\nY: %d\nCHUNK: [ %d , %d ]" % [
			fps,
			ram_usage,
			vram_usage,
			player.global_position.x, 
			player.global_position.y, 
			chunk_x, 
			chunk_y
		]
