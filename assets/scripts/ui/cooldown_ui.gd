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
		var time_left = max_time - current_time
		
		cooldown_label.text = "%.1f" % time_left + "s"
		value = min((current_time / max_time) * 100.0, 100.0)

# --- REAKCJE NA SYGNAŁY ---

func _on_cooldown_started() -> void:
	# Gracz uderzył! Budzimy skrypt UI do życia:
	cooldown_label.show()
	set_process(true) # Włącza wykonywanie funkcji _process()

func _on_cooldown_ready() -> void:
	# Odnawianie się skończyło. Usypiamy skrypt!
	set_process(false) # Wyłącza funkcję _process() - ZERO zużycia procesora!
	
	value = max_value
	cooldown_label.text = "Gotowe!"
	# Opcjonalnie: cooldown_label.hide()
	
	#todo stun od enemy nie ładuje w ui
