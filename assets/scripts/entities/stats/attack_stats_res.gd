extends Resource

class_name AttackStatsComponent

# Zmienna przechowująca czas, jeśli jest równy max to można wykonać atak.
var cooldown_timer : float = 1.0
# Zmienna przechowująca aktualny limit cooldowna (zależne od itemu/ręki...) 
var actual_cooldown : float = 1.0
# nie tylko weapons 
# trzeba będzie zmienić nazwę tego komponentu ale nie wiem na jaką jeszcze


## Hand attack.
@export var damage : int = 10
## Hand stun time.
@export var stun_time : float = 0.25
## Hand cooldown.
@export var hand_cooldown : float = 1.0


# Damage buff
@export var damage_adder : float = 0.0
@export var damage_multiplier : float = 1.0

# Stun buff
@export var stun_adder : float = 0.0
@export var stun_multiplier : float = 1.0

# Cooldown buff
@export var cooldown_adder : float = 0.0
@export var cooldown_multiplier : float = 1.0

func total_hand_damage() -> int :
	return int( ( damage + damage_adder ) * damage_multiplier )

func total_stun() -> float :
	return ( stun_time + stun_adder ) * stun_multiplier

func total_actual_cooldown() -> float :
	return ( actual_cooldown + cooldown_adder ) * cooldown_multiplier

func apply_stun(seconds : float) -> void :
	cooldown_timer -= seconds

func can_attack() -> bool :
	if cooldown_timer < total_actual_cooldown() :
		return false
	return true

func attack(target : CharacterBody2D) -> void :
	target.health_stats_script.take_damage(total_hand_damage())
	target.attack_stats_script.apply_stun(total_stun())
	
	cooldown_timer = 0.0

func attack_cooldown_process(delta : float) -> void :
	if cooldown_timer < total_actual_cooldown():
		cooldown_timer += delta

## Ustawia cooldown timer aby odliczał od początku.
func reset_cooldown() -> void:
	cooldown_timer = 0.0
