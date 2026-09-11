extends Node
class_name AIPhaseController

@export var phases: Array[AIPhase] = []

var controller: AIController
var stats: MonitoredLifeStatsComponent
var current_phase_index: int = -1

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	stats = controller.entity.health_stats_script
	
	if stats:
		stats.health_updated.connect(_on_health_updated)
		
	# Sortujemy fazy malejąco po HP, aby upewnić się, że odpalamy je w odpowiedniej kolejności
	phases.sort_custom(func(a: AIPhase, b: AIPhase): return a.health_threshold > b.health_threshold)

func _on_health_updated(current_health: int, maximum_health: int) -> void:
	if maximum_health <= 0 or phases.is_empty(): return
	
	var health_pct = float(current_health) / float(maximum_health)
	
	for i in range(phases.size()):
		# Jeśli zdrowie spadło poniżej progu, a faza nie była jeszcze odpalona
		if health_pct <= phases[i].health_threshold and current_phase_index < i:
			_enter_phase(i)

func _enter_phase(index: int) -> void:
	current_phase_index = index
	var phase = phases[index]
	print("[BOSS] " + controller.entity.name + " wchodzi w fazę: " + phase.phase_name)
	
	# 1. Aktualizacja Profilu Zachowania (Szybkość, Kiting)
	if phase.new_behavior_profile != null:
		controller.behavior_profile = phase.new_behavior_profile
		if controller.perception:
			controller.perception.detection_distance = phase.new_behavior_profile.detection_distance
			
	# 2. Aktualizacja Umiejętności
	if controller.combat:
		controller.combat.abilities = phase.new_abilities.duplicate()
		controller.combat._ability_cooldowns.clear()
		for ab in controller.combat.abilities:
			if ab != null:
				controller.combat._ability_cooldowns[ab] = 0.0 # Umiejętności w nowej fazie są gotowe od razu!
				
	# 3. Leczenie (Opcjonalne)
	if phase.heal_percent_on_enter > 0.0:
		var heal_amount = int(stats.max_health * phase.heal_percent_on_enter)
		stats.heal(heal_amount)
		
	# Dodatkowo wymuszamy krótki przystanek na "zaryczenie/transformację" Bossa
	if controller.state_machine:
		controller.state_machine.change_state("Idle")
