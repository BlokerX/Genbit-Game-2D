extends Resource

class_name LifeStatsComponent

signal health_changed(new_health, max_health)
signal died

@export_group("Zdrowie")
@export var health : int = 100
@export var max_health : int = 100

@export_group("Pancerz i Obrona")
@export var base_armor: float = 0.0
var armor_adder: float = 0.0
var armor_multiplier: float = 1.0

@export_group("Odporności i Ciernie")
## Odporność na kontrolę tłumu (0.0 = 0%, 1.0 = 100% niewrażliwości na odrzut i ogłuszenie)
@export_range(0.0, 1.0) var cc_resistance: float = 0.0

## Płaskie obrażenia zwrotne (zadawane atakującemu przy każdym otrzymanym ciosie)
@export var thorns_damage: int = 0
## Procent otrzymanych obrażeń (po redukcji przez pancerz) odbijanych w atakującego
@export_range(0.0, 1.0) var thorns_percent: float = 0.0

func get_total_armor() -> int:
	return int((base_armor + armor_adder) * armor_multiplier)

# jeśli < 0 to jest niesmiertelna
func is_alive() -> bool :
	if health == 0 :
		return false
	return true

func take_damage(damage : int, armor_penetration : float) -> void :
	# Pancerz jest redukowany o procent penetracji (np. 0.3 oznacza, że ignorujemy 30% pancerza)
	var effective_armor = float(get_total_armor()) * (1.0 - armor_penetration)
	var final_damage = damage - int(effective_armor)
	
	# Zabezpieczenie: cios zawsze zadaje co najmniej 1 punkt obrażeń
	final_damage = max(1, final_damage)
	
	health -= final_damage
	health_changed.emit(health, max_health) # Informujemy UI
	print("Otrzymano cios! Obrażenia bazowe: ", damage, " | Zablokowano: ", get_total_armor(), " | Otrzymano: ", final_damage)
	
	if health <= 0 :
		kill()

func heal(healing : int) -> void :
	health += healing
	if health > max_health :
		health = max_health
	health_changed.emit(health, max_health) # Informujemy UI

func heal_completely() -> void :
	health = max_health
	health_changed.emit(health, max_health)

func kill() -> void :
	health = 0
	health_changed.emit(health, max_health)
	died.emit() # Odpalamy sygnał śmierci!
	
func boost_max_health(boost : int) -> void :
	if boost > 0 :
		max_health += boost

func reduce_max_health(reduction : int) -> void :
	# validation
	if reduction <= 0:
		return
	
	if max_health - reduction > 0 :
		max_health -= reduction
		
	# else :
		# przypadek gdy max_health było by zerowe 
		# (ujemne też daje zerowe w tym algorytmie) :
		# problematyczne ->
		# max_health = 0 # nieporządana sytuacja
		# kill()
		
	# Żeby zdrowie nie było większe niż limit:
	if health > max_health :
		heal_completely()

func reset_stats() :
	max_health = 100 # default_value = 100
	heal_completely()
