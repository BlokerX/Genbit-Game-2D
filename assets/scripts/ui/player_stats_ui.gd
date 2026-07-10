extends Control

@export var player: PlayerCharacter
@export var damage_label: Label
@export var crit_rate_label: Label
@export var range_label: Label
@export var speed_label: Label # Opcjonalnie, jeśli wyciągniesz speed z movement component

func _ready() -> void:
	if player:
		# Odświeżamy statystyki za każdym razem, gdy zmieni się ekwipunek (inna broń = inne staty)
		if player.inventory:
			player.inventory.inventory_updated.connect(update_stats_display)
		
		# Inicjalne załadowanie
		update_stats_display()

func update_stats_display() -> void:
	if not player or not player.interaction_and_attack_stats_script:
		return
		
	var stats = player.interaction_and_attack_stats_script
	
	# Zczytywanie wartości z pomocą metod, które już napisałeś
	var damage = stats.get_total_damage()
	var crit = stats.get_total_critical_rate() * 100.0 # Konwersja na procenty
	var atk_range = stats.get_total_range()
	
	# Aktualizacja tekstów
	damage_label.text = "DMG: " + str(damage)
	crit_rate_label.text = "CRIT: %.1f%%" % crit
	range_label.text = "RANGE: " + str(atk_range)
	
	# (Opcjonalnie) Pobranie prędkości ruchu, jeśli używasz PlayerMovementComponent
	if player.movement_universal_script and "moveSpeed" in player.movement_universal_script:
		speed_label.text = "SPEED: " + str(player.movement_universal_script.moveSpeed)
