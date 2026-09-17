extends Node
class_name ThreatAssessmentComponent

@export_category("Skanowanie Zagrożeń")
@export var scan_radius: float = 350.0
@export var base_fear: float = 0.0
@export var max_fear: float = 0.95

var controller: AIController

# Flagi do strafingu
var _strafe_direction: float = 1.0
var _strafe_timer: float = 0.0

func initialize(ai_controller: AIController) -> void:
	controller = ai_controller

func process_threats(delta: float) -> void:
	var blackboard = controller.blackboard
	var entity = controller.entity
	var profile = controller.behavior_profile
	
	if not profile or not profile.intelligent_movement:
		return

	var total_avoidance := Vector2.ZERO
	var current_threat := base_fear
	
	# Zmiana kierunku strafingu co losowy czas (aby AI "zygzakowało")
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_direction = 1.0 if randf() > 0.5 else -1.0
		_strafe_timer = randf_range(0.8, 2.5)

	# =========================================================================
	# 1. OCENA BRONI GRACZA (Schodzenie z lufy - Kiting & Strafing)
	# =========================================================================
	if blackboard.target and blackboard.target.has_method("get_inventory"):
		var inv = blackboard.target.get_inventory()
		if inv:
			var weapon = inv.get_current_item()
			if weapon and weapon.data and weapon.data.components:
				var weapon_threat = _evaluate_weapon_threat(weapon.data.components)
				current_threat = max(current_threat, weapon_threat)
				
				if weapon_threat >= 0.7:
					# Zamiast uciekać do tyłu, schodzimy BOKIEM (krzyżowo)
					# Bierzemy wektor od nas do gracza, a następnie znajdujemy jego wektor normalny (prostopadły).
					var dir_to_player = entity.global_position.direction_to(blackboard.target.global_position)
					var tangent = Vector2(-dir_to_player.y, dir_to_player.x) * _strafe_direction
					
					# Waga strafingu rośnie wraz z siłą broni
					total_avoidance += tangent * (weapon_threat * 1.5)

	# =========================================================================
	# 2. OMIJANIE PUŁAPEK I MIN (Analiza Węzłów Sceny)
	# =========================================================================
	# UWAGA: Używamy metody get_nodes_in_group(), ponieważ jest w 100% niezawodna 
	# i nie zależy od masek fizyki. Jeśli mina tam jest - zostanie znaleziona.
	var hazards = get_tree().get_nodes_in_group("Hazard")
	
	for hazard in hazards:
		# Zabezpieczenie przed usuniętymi obiektami w tej samej klatce
		if not is_instance_valid(hazard): 
			continue
		
		# Zabezpieczenie: AI nie ucieka przed swoimi własnymi rzutkami/bombami!
		if "shooter" in hazard and hazard.shooter == entity:
			continue
			
		var dist = entity.global_position.distance_to(hazard.global_position)
		
		# Omijamy tylko te, które znajdują się w polu widzenia / skanowania
		if dist < scan_radius:
			var hazard_threat = 0.95
			if dist < 150.0:
				hazard_threat = max_fear # Panika z bliska!
				
			current_threat = max(current_threat, hazard_threat)
			
			var dir_to_hazard = entity.global_position.direction_to(hazard.global_position)
			var dir_away = -dir_to_hazard
			
			# OBLICZANIE ŚCIEŻKI OMIJANIA
			var current_move_dir = entity.velocity.normalized()
			if current_move_dir == Vector2.ZERO and blackboard.target:
				current_move_dir = entity.global_position.direction_to(blackboard.target.global_position)
				
			# Jeśli AI idzie prosto na minę (wektor ruchu celuje prosto w nią)
			if current_move_dir.dot(dir_to_hazard) > 0.3:
				var tangent = Vector2(-dir_to_hazard.y, dir_to_hazard.x)
				# Wybieramy ten bok miny, w który i tak się już lekko odchylamy, aby było to płynne
				if current_move_dir.dot(tangent) < 0:
					tangent = -tangent
				# Wypychamy wektor "do tyłu i w bok"
				dir_away = (dir_away + tangent * 3.0).normalized()

			# Siła odpychania zależy od dystansu - im bliżej bomby, tym mocniej AI od niej ucieka
			var distance_weight = clamp(1.0 - (dist / scan_radius), 0.0, 1.0)
			
			# Potężny mnożnik (4.0), żeby zmuszenie do wyhamowania przed miną zadziałało przeciwko ścieżce agenta
			total_avoidance += dir_away * distance_weight * 4.0 

	# Zapisujemy wyniki do Blackboarda
	blackboard.threat_level = clamp(current_threat, 0.0, 1.0)
	blackboard.avoidance_vector = total_avoidance


func _evaluate_weapon_threat(components: Array) -> float:
	for comp in components:
		if comp is RangedWeaponComponent:
			# Zwykłe zagrożenie bronią palną
			if comp.attack_data and comp.attack_data.damage >= 20:
				return 0.85 
			return 0.45 
		elif comp is MeleeWeaponComponent:
			# Zagrożenie mniejsze z dystansu
			return 0.30 
	return 0.10
