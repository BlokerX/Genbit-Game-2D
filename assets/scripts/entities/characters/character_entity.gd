@abstract
extends CharacterBody2D

class_name CharacterEntity

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu i statystyk:
@export var movement_universal_script : MovementComponent
@export var health_stats_script : MonitoredStatsComponent 
@export var interaction_and_attack_stats_script : InteractionAndAttackStatsComponent

# GUI elements:
@export var health_points_bar : ProgressBar
@export var health_points_label : Label

@export var character_sprite : Sprite2D

@export var effects_collector : Node

#region Główne funkcje silnikowe

func _ready():
	# Podłączenie sygnału z komponentu statystyk do funkcji death_sequence
	if health_stats_script:
		health_stats_script.died.connect(_on_character_died)
		health_stats_script.health_changed.connect(on_health_changed)
		
	# Inicjalizacja UI...
	health_stats_script.health_points_bar = health_points_bar
	health_stats_script.health_points_label = health_points_label
	health_stats_script.change_health_points_bar_max_value()
	
	health_stats_script.update_helath_points_bar()

func _process(_delta):
	pass

func _physics_process(_delta):
	pass

#endregion

#region Obsługa sygnałów

# Funkcja wywoływana TYLKO gdy postać zginie
func _on_character_died():
	print("Entity character has been killed successfully!")
	health_stats_script.heal_completely()
	respawn()

func on_health_changed(_new_health, _max_health):
	health_stats_script.update_helath_points_bar()

#endregion

#region Obsługa systemu akcji (Effect)

## Funkcja pozwalająca na nałożenie dowolnego efektu na entity character.
func receive_effect(effect: Effect) -> bool:
	# Przekazujemy 'self' (czyli entity character), ponieważ skrypt rozszerza CharacterBody2D
	var success = effect.apply_effect(self)
	if success:
		print("Entity character otrzymał efekt: ", effect.effect_name)
	else:
		print("Nie udało się nałożyć efektu na entity character.")
	return success

## Funkcja usuwająca wszystkie efekty nałożone na postać
func clear_all_effects() -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			active_effect.set_process(false) # to jest dodane %
			# Prawidłowe wymuszenie zakończenia efektu poprzez skrypt ActiveEffect
			if active_effect.has_method("end_effect"):
				active_effect.end_effect()
			else:
				active_effect.queue_free()
		print("Usunięto wszystkie efekty z entity character.")
		return
	print("Nie znaleziono kontenera efektów w entity character.")

#endregion

## Testowa metoda respawnu.
func respawn():
	position = respawnVector
	velocity.x = 0
	velocity.y = 0
	# Przy odrodzeniu usuwamy z postaci wszystkie nałożone na nią statusy
	clear_all_effects()
