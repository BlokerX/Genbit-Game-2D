@abstract
extends CharacterBody2D

class_name CharacterEntity

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu i statystyk:
@export var movement_universal_script : MovementComponent
@export var health_stats_script : MonitoredStatsComponent 
@export var attack_stats_script : AttackStatsComponent

# GUI elements:
@export var health_points_bar : ProgressBar
@export var health_points_label : Label

@export var character_sprite : Sprite2D

@export var effects_collector : Node

func _ready():
	# Health points bar initialization
	health_stats_script.health_points_bar = health_points_bar
	health_stats_script.health_points_label = health_points_label
	health_stats_script.change_health_points_bar_max_value()

func _process(_delta):
	#region Stats GUI Procedure
	health_stats_script.update_helath_points_bar()
	#endregion

func _physics_process(_delta):
	# TYMCZASOWE ROZWIĄZANIE TESTOWE !!!
	# Respawn in case of death
	if !health_stats_script.is_alive() :
		print("Entity character has killed successfull!")
		health_stats_script.heal_completely()
		respawn()
		return

## Funkcja pozwalająca na nałożenie dowolnego efektu na entity character.
func receive_effect(effect: Effect) -> void:
	# Przekazujemy 'self' (czyli entity character), ponieważ skrypt rozszerza CharacterBody2D
	var success = effect.apply_effect(self)
	if success:
		print("Entity character otrzymał efekt: ", effect.effect_name)
	else:
		print("Nie udało się nałożyć efektu na entity character.")

func respawn():
		position = respawnVector
		velocity.x = 0
		velocity.y = 0
