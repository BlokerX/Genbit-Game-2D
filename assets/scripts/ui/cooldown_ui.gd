extends ProgressBar
## Pasek wizualizacji czasu odnowienia akcji (Cooldown / Przeładowanie / Ogłuszenie) na HUD-zie gracza.

const READY_TEXT: String = "Gotowe!"

@export var player: PlayerCharacter
@export var cooldown_label: Label

func _ready() -> void:
	if player != null and player.interaction_and_attack_stats_script != null:
		var stats: InteractionAndAttackStatsComponent = player.interaction_and_attack_stats_script
		# Podłączamy sygnały z komponentu gracza
		if not stats.cooldown_started.is_connected(_on_cooldown_started):
			stats.cooldown_started.connect(_on_cooldown_started)
		if not stats.cooldown_ready.is_connected(_on_cooldown_ready):
			stats.cooldown_ready.connect(_on_cooldown_ready)

		# Na starcie gry sprawdzamy stan gotowości (usypia skrypt UI, jeśli broń jest gotowa)
		if stats.can_attack():
			_on_cooldown_ready()
		else:
			_on_cooldown_started()

## Ta funkcja kręci się co klatkę, ALE TYLKO GDY JEST WŁĄCZONA!
func _process(_delta: float) -> void:
	if player == null or player.interaction_and_attack_stats_script == null:
		return

	var stats: InteractionAndAttackStatsComponent = player.interaction_and_attack_stats_script
	var time_left: float = stats.get_remaining_cooldown()

	if time_left <= 0.0:
		_on_cooldown_ready()
		return

	if cooldown_label != null:
		cooldown_label.text = "%.1fs" % time_left

	# Korzystamy z metody eksperckiej get_cooldown_progress_ratio(), która płynnie skaluje pasek
	# od 0 do max_value zarówno przy zwykłym ataku, jak i podczas Stuna czy Przeładowania!
	value = clampf(stats.get_cooldown_progress_ratio() * max_value, 0.0, max_value)

# --- REAKCJE NA SYGNAŁY ---
func _on_cooldown_started() -> void:
	# Gracz uderzył, przeładowuje lub otrzymał Stun! Budzimy skrypt UI do życia:
	if cooldown_label != null:
		cooldown_label.show()
	set_process(true) # Włącza wykonywanie funkcji _process()

func _on_cooldown_ready() -> void:
	# Odnawianie się skończyło. Usypiamy skrypt!
	set_process(false) # Wyłącza funkcję _process() - ZERO zużycia procesora!
	value = max_value
	if cooldown_label != null:
		cooldown_label.text = READY_TEXT
