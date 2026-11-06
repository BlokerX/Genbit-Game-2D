extends ProgressBar 

@export var player : PlayerCharacter
@export var cooldown_label : Label 

func _ready() -> void:
	if player != null and player.interaction_and_attack_stats_script != null:
		var stats = player.interaction_and_attack_stats_script
		# Podłączamy sygnały z komponentu gracza
		stats.cooldown_started.connect(_on_cooldown_started)
		stats.cooldown_ready.connect(_on_cooldown_ready)

		# Na starcie gry wywołujemy stan gotowości, co od razu uśpi skrypt UI
		_on_cooldown_ready()

# Ta funkcja kręci się co klatkę, ALE TYLKO GDY JEST WŁĄCZONA!
func _process(_delta: float) -> void:
	if player != null and player.interaction_and_attack_stats_script != null:
		var current_time = player.interaction_and_attack_stats_script.cooldown_timer
		var max_time = player.interaction_and_attack_stats_script.get_total_actual_cooldown()

		var time_left = max(0.0, max_time - current_time)
		cooldown_label.text = "%.1f" % time_left + "s"

		# --- ZABEZPIECZENIE (Obsługuje również ujemny current_time podczas Stuna i Przeładowania) ---
		if time_left > max_time and time_left > 0.0:
			# Gdy stun/reload trwa dłużej niż bazowy cooldown broni, pokazujemy postęp od 0 do 100%
			value = clamp((1.0 - (time_left / (max_time - min(0.0, current_time)))) * 100.0, 0.0, 100.0)
		elif max_time > 0.0:
			value = clamp((current_time / max_time) * 100.0, 0.0, 100.0)
		else:
			value = 100.0

# --- REAKCJE NA SYGNAŁY ---
func _on_cooldown_started() -> void:
	# Gracz uderzył lub otrzymał Stun! Budzimy skrypt UI do życia:
	cooldown_label.show()
	set_process(true) # Włącza wykonywanie funkcji _process()

func _on_cooldown_ready() -> void:
	# Odnawianie się skończyło. Usypiamy skrypt!
	set_process(false) # Wyłącza funkcję _process() - ZERO zużycia procesora!
	value = max_value
	cooldown_label.text = "Gotowe!"
