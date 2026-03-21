extends Resource

class_name LifeStatsComponent

signal health_changed(new_health, max_health)
signal died

@export var health : int = 100
@export var max_health : int = 100

# jeśli < 0 to jest niesmiertelna
func is_alive() -> bool :
	if health == 0 :
		return false
	return true

func take_damage(damage : int) -> void :
	health -= damage
	health_changed.emit(health, max_health) # Informujemy UI
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
		pass
	
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
