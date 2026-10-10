extends CharacterEntity
class_name AICharacterEntity

const FeedbackCueType = preload("res://assets/scripts/audio_system/feedback_cue.gd")
const VISUAL_ORIGIN_TARGET := 1

@export_group("Oprawa dźwiękowa")
## Domyślny dźwięk ataku przeciwnika; indywidualny cue broni może go nadpisać.
@export var attack_feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemy_attack.tres"
)
## Dźwięk przyjęcia obrażeń przez przeciwnika.
@export var damage_received_feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemy_damage_received.tres"
)
## Dźwięk zadania obrażeń przez przeciwnika.
@export var damage_dealt_feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemy_damage_dealt.tres"
)
## Dźwięk śmierci przeciwnika.
@export var death_feedback_cue: FeedbackCueType = preload(
	"res://assets/data/feedback/enemy_death.tres"
)

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

## Udostępnia dispatcherowi wspólny punkt odtwarzania oprawy ataku AI.
func play_item_feedback(cue: FeedbackCueType, target: Node2D) -> void:
	var selected_cue := cue if cue != null else attack_feedback_cue
	if selected_cue == null:
		return
	var effect_position := global_position
	if (
		selected_cue.visual_origin == VISUAL_ORIGIN_TARGET
		and is_instance_valid(target)
	):
		effect_position = target.global_position
	GameFeedback.play_cue(selected_cue, character_sprite, effect_position, self)

## Odtwarza cue po potwierdzonym trafieniu zadanym przez przeciwnika.
func notify_damage_dealt(target: Node2D) -> void:
	if damage_dealt_feedback_cue == null:
		return
	var effect_position := target.global_position if is_instance_valid(target) else global_position
	GameFeedback.play_cue(damage_dealt_feedback_cue, null, effect_position, self)

# Przejęta logika ruchu, z której korzysta StateChase
func set_movement_target(movement_target: Vector2) -> void:
	if navigation_agent:
		navigation_agent.target_position = movement_target

# --- SYSTEM ZEMSTY ---
func receive_effect(effect: Effect) -> bool:
	var success = super.receive_effect(effect)
	if success and effect is DamageEffect and damage_received_feedback_cue != null:
		GameFeedback.play_cue(
			damage_received_feedback_cue,
			character_sprite,
			global_position,
			self
		)
	
	if success and effect is DamageEffect and effect.source_entity != null:
		var attacker = effect.source_entity
		if attacker is CharacterEntity and attacker != self and faction_component:
			# Uruchamiamy złożoną procedurę z Frakcji (Zemsta + Wołanie o pomoc)
			faction_component.process_revenge(attacker)
			
	return success

## Odtwarza dźwięk śmierci przed bazową obsługą i usunięciem przeciwnika.
func _on_character_died() -> void:
	if (
		not is_dead
		and not (has_meta("is_immortal") and get_meta("is_immortal") == true)
		and death_feedback_cue != null
	):
		GameFeedback.play_cue(death_feedback_cue, character_sprite, global_position, self)
	super()

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
