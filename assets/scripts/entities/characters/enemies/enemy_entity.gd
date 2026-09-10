extends CharacterEntity
class_name EnemyEntity

#region AI
@export_category("AI")
@export var ai_controller: AIController
#endregion

func _ready() -> void:
	super()
	
	if not entity_spawn_requested.is_connected(_on_spawn_requested):
		entity_spawn_requested.connect(_on_spawn_requested)

	if ai_controller == null:
		ai_controller = get_node_or_null("AIController")
		if ai_controller == null:
			push_warning("%s nie posiada przypisanego AIController." % name)
			return

	ai_controller.initialize(self)

func _on_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	var parent = get_parent()
	if parent:
		parent.call_deferred("add_child", spawned_node)
		spawned_node.global_position = spawn_pos

# --- NOWOŚĆ: Uczymy wroga odpowiadać na zapytanie o ekwipunek ---
# Dzięki temu broń strzelecka wie, gdzie szukać funkcji przeładowania!
func get_inventory() -> Node:
	if ai_controller:
		return ai_controller.get_node_or_null("AIInventoryController")
	return null
