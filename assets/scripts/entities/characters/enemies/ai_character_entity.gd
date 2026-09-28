extends CharacterEntity
class_name AICharacterEntity

@export_category("AI")
@export var ai_controller: AIController

var navigation_agent: NavigationAgent2D

func _ready() -> void:
	super()
	
	# Automatyczne szukanie agenta nawigacji
	navigation_agent = get_node_or_null("NavigationAgent2D")
	
	if not entity_spawn_requested.is_connected(_on_spawn_requested):
		entity_spawn_requested.connect(_on_spawn_requested)
		
	if ai_controller == null:
		ai_controller = get_node_or_null("AIController")
		
	if ai_controller == null:
		push_warning("%s nie posiada przypisanego AIController." % name)
		return
		
	ai_controller.initialize(self)
	
	# Podłączenie ItemThrowerComponent do wroga
	var thrower = get_node_or_null("ItemThrowerComponent")
	if thrower and not thrower.entity_spawn_requested.is_connected(_on_spawn_requested):
		thrower.entity_spawn_requested.connect(_on_spawn_requested)

func _on_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	var parent = get_parent()
	if parent:
		parent.call_deferred("add_child", spawned_node)
		spawned_node.set_deferred("global_position", spawn_pos)

func get_inventory() -> Node:
	if ai_controller:
		return ai_controller.get_node_or_null("AIInventoryController")
	return null

# Przejęta logika ruchu, z której korzysta StateChase
func set_movement_target(movement_target: Vector2) -> void:
	if navigation_agent:
		navigation_agent.target_position = movement_target

# --- SYSTEM ZEMSTY ---
func receive_effect(effect: Effect) -> bool:
	var success = super.receive_effect(effect)
	
	if success and effect is DamageEffect and effect.source_entity != null:
		var attacker = effect.source_entity
		if attacker is CharacterEntity and attacker != self and faction_component:
			# Uruchamiamy złożoną procedurę z Frakcji (Zemsta + Wołanie o pomoc)
			faction_component.process_revenge(attacker)
			
	return success

# --- SYSTEM PRZEBUDZENIA Z CHUNKA (Naprawa "Choroby Hibernacyjnej") ---

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_wake_up_from_hibernation")

func _wake_up_from_hibernation() -> void:
	# TARCZA 1: Je li Streamer zd  nas usun  przed odpaleniem tej funkcji - przerywamy!
	if not is_inside_tree():
		return
		
	is_frozen = false
	
	# --- 1. NAPRAWA STANU WALKI (Odblokowanie Softlocka Zdolności) ---
	# Jeśli przeciwnik został wyciągnięty z mapy w trakcie rzucania skilla,
	# flaga 'is_casting_ability' zacięła się na stałe. Wymuszamy jej reset.
	if ai_controller:
		var combat_ctrl = ai_controller.get_node_or_null("AICombatController")
		if combat_ctrl:
			combat_ctrl.is_casting_ability = false
			
	# --- 2. ZABICIE ZAWIESZONYCH LOTÓW/ANIMACJI ---
	# Zabijamy stare Tweeny, by przeciwnik (np. boss z JumpSmashAbility)
	# nie kontynuował starego lotu po wybudzeniu z hibernacji.
	for t in active_tweens:
		if t and t.is_valid():
			t.kill()
	active_tweens.clear()
	
	if interaction_and_attack_stats_script:
		interaction_and_attack_stats_script.reset_cooldown()
		
	# --- 3. TWARDY RESTART SENSORÓW FIZYCZNYCH ---
	for area in find_children("*", "Area2D", true, false):
		if area.monitoring:
			area.monitoring = false
			area.monitoring = true
			
	for ray in find_children("*", "RayCast2D", true, false):
		if ray.enabled:
			ray.enabled = false
			ray.enabled = true
			ray.force_raycast_update()

	# Czekamy na przeliczenie kolizji
	#await get_tree().physics_frame
	#await get_tree().physics_frame
	
	# TARCZA 2: Zabezpieczenie po odczekaniu klatek
	if not is_inside_tree():
		return
	
	# --- 4. RESET MÓZGU ---
	if ai_controller and ai_controller.has_method("reset_state"):
		ai_controller.reset_state()
		
	if ai_controller and ai_controller.has_method("force_target_scan"):
		ai_controller.force_target_scan()
