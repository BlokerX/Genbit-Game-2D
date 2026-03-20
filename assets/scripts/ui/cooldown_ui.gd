extends ProgressBar # Zmień to na ProgressBar lub TextureProgressBar, jeśli podpinasz to pod pasek

@export var player : PlayerCharacter

# Referencja do węzła tekstowego.
# Pamiętaj, aby w Inspektorze przeciągnąć swój węzeł Label do tego pola!
@export var cooldown_label : Label 

func _process(_delta: float) -> void:
	if player != null and player.interaction_and_attack_stats_script != null:
		
		var current_time = player.interaction_and_attack_stats_script.cooldown_timer
		var max_time = player.interaction_and_attack_stats_script.total_actual_cooldown()
		
		# Obliczamy ile czasu ZABRAKŁO do końca cooldownu
		var time_left = max_time - current_time
		
		# Jeśli wciąż trwa odnawianie (zostało więcej niż 0 sekund)
		if time_left > 0:
			cooldown_label.visible = true
			
			# Formatujemy tekst do 1 miejsca po przecinku, np. "1.2s"
			cooldown_label.text = "%.1f" % time_left + "s"
			
			# (Opcjonalnie) Jeśli używasz też paska, możesz go tutaj nadal aktualizować:
			var fill_percentage = (current_time / max_time) * 100.0
			value = min(fill_percentage, 100.0)
			
		else :
			# Albo zamiast ukrywania możesz wyświetlić inny tekst, np:
			value = max_value
			cooldown_label.text = "Gotowe!"
