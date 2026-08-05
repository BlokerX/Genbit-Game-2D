@abstract
extends CharacterBody2D

class_name CharacterEntity

# Zmienne respawnu:
@export var respawnVector := Vector2(512, 360)

# Komponent ruchu i statystyk:
@export var movement_universal_script : MovementComponent
@export var health_stats_script : MonitoredLifeStatsComponent 
@export var interaction_and_attack_stats_script : InteractionAndAttackStatsComponent
@export var loot_drop_script : LootDropComponent

## Indywidualna grubość postaci do walki ---
@export var combat_radius: float = 40.0

@export var character_sprite : Sprite2D

@export var effects_collector : Node

@export var destroy_entity_after_die : bool = true

#region Główne funkcje silnikowe

func _ready():
	# Podłączenie sygnału z komponentu statystyk do funkcji death_sequence
	if health_stats_script:
		health_stats_script.died.connect(_on_character_died)

func _process(_delta):
	pass

func _physics_process(_delta):
	pass

#endregion

#region Obsługa sygnałów

# Funkcja wywoływana TYLKO gdy postać zginie
func _on_character_died():
	# Jeśli przypisaliśmy skrypt w Inspektorze
	if loot_drop_script:
		loot_drop_script.perform_drop(self)
	
	print(self.name + " has been killed successfully!")
	
	# Opóźniamy leczenie i respawn do końca aktualnej klatki logicznej silnika
	# call_deferred("respawn_sequence")
	
	# todo poprowadzić tu jakoś koniec rozgrywki
	if destroy_entity_after_die :
		self.queue_free()
		print(self.name + " został zwolniony z istnienia.")
	else : call_deferred("respawn_sequence")
	

# Sekwencja respawnu, Uruchomi się, gdy wszystkie efekty (w tym zamrożenie) skończą się nakładać
func respawn_sequence():
	health_stats_script.heal_completely()
	
	position = respawnVector
	velocity.x = 0
	velocity.y = 0
	
	clear_all_effects()

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

## Funkcja usuwająca konkretny efekt po jego nazwie (używana przez pokoje z hazardami)
func remove_effect_by_name(eff_name: String) -> void:
	if effects_collector != null:
		for active_effect in effects_collector.get_children():
			# Zabezpieczenie Duck Typing
			if active_effect.get("effect_resource") != null and active_effect.effect_resource.effect_name == eff_name:
				if active_effect.has_method("end_effect"):
					active_effect.end_effect()
				else:
					active_effect.queue_free()
				print("Usunięto efekt środowiskowy: ", eff_name)

#endregion
