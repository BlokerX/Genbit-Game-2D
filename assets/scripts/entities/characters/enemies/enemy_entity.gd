extends CharacterEntity
class_name EnemyEntity

@export_category("AI")
@export var ai_controller: AIController

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
	
	# --- NAPRAWA DROPU --- 
	# Podłączamy ItemThrowerComponent do wroga, żeby zlecenia wyrzutu przedmiotów wychodziły w świat
	var thrower = get_node_or_null("ItemThrowerComponent")
	if thrower and not thrower.entity_spawn_requested.is_connected(_on_spawn_requested):
		thrower.entity_spawn_requested.connect(_on_spawn_requested)

func _on_spawn_requested(spawned_node: Node2D, spawn_pos: Vector2) -> void:
	var parent = get_parent()
	if parent:
		# Zlecenie dodania do drzewa w następnej wolnej klatce
		parent.call_deferred("add_child", spawned_node)
		# Ustawienie pozycji dopiero po wygenerowaniu węzła!
		spawned_node.set_deferred("global_position", spawn_pos)

func get_inventory() -> Node:
	if ai_controller:
		return ai_controller.get_node_or_null("AIInventoryController")
	return null
