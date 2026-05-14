extends ProgressBar # Lub cokolwiek innego, co trzyma Twoje UI
class_name HealthBar

# Tu podpinasz tylko zasób ze statystykami gracza
@export var player_stats: MonitoredStatsComponent

# Zmienna na etykietę (nie eksportujemy jej, bo skrypt znajdzie ją sam)
var health_points_label: Label = null

func _ready() -> void:
	# 1. AUTOMATYCZNE SZUKANIE: Skrypt szuka w swoich dzieciach węzła typu Label
	for child in get_children():
		if child is Label:
			health_points_label = child
			break # Znaleźliśmy, przerywamy pętlę!
			
	# 2. Podłączenie do czystego zasobu (Resource)
	if player_stats != null:
		# Podłączamy ucho do sygnałów z Zasobu
		player_stats.health_changed.connect(_on_health_updated)
		player_stats.max_health_changed.connect(_on_max_health_changed)
		
		# Inicjalizujemy UI na starcie, żeby nie było pustych pasków
		_on_max_health_changed(player_stats.max_health)
		_on_health_updated(player_stats.health, player_stats.max_health)

# Reakcja na sygnał zmiany aktualnego HP
func _on_health_updated(current_health: int, maximum_health: int) -> void:
	self.value = current_health
	health_points_label.text = str(current_health) + " / " + str(maximum_health)

# Reakcja na sygnał zwiększenia/zmniejszenia maksymalnego HP
func _on_max_health_changed(new_max_health: int) -> void:
	self.max_value = new_max_health
