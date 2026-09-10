extends CharacterEntity
class_name EnemyEntity

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
