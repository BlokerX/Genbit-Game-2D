@tool
extends BaseWorldSpawner
## Zaawansowany spawner obiektów fizycznych, przeszkód, pułapek i min.
## Reaguje na te same bodźce co spawner przeciwników i pozwala na pełne zarządzanie cyklem życia.
class_name ObjectSpawner

const GIZMO_BOX_HALF_SIZE: float = 12.0

@export_group("Konfiguracja Obiektu")
## Zasób określający co ma się pojawić.
## Przeciągnij tutaj konkretną scenę (PackedScene) LUB pulę obiektów (ObjectSpawnPool).
@export var spawn_resource: Resource
## Jeśli postawiony obiekt należy do klasy PlacedObject (np. mina, postawiona skrzynka), 
## możesz tu przypisać ItemData. Obiekt zapamięta ten przedmiot i wyrzuci go po zniszczeniu/podniesieniu.
@export var drop_item_data: ItemData

func _has_valid_spawn_configuration() -> bool:
	return spawn_resource != null

func _create_spawn_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	var spawned_node: Node = _create_instance()
	if spawned_node != null:
		_inject_placed_object_data(spawned_node)
		nodes.append(spawned_node)
	return nodes

func _create_instance() -> Node:
	if spawn_resource is PackedScene:
		return (spawn_resource as PackedScene).instantiate()
	elif spawn_resource is ObjectSpawnPool:
		var scene: PackedScene = (spawn_resource as ObjectSpawnPool).get_random_object_scene()
		return scene.instantiate() if scene != null else null
	return null

## Wstrzykuje duszę przedmiotu do obiektu typu PlacedObject (aby wypadł po zebraniu klawiszem F).
func _inject_placed_object_data(instance: Node) -> void:
	if instance is PlacedObject and drop_item_data != null:
		var unique_data: ItemData = drop_item_data.duplicate(true)
		var item_instance: ItemInstance = ItemInstance.new(unique_data, 1)

		# Aplikacja maksymalnej wytrzymałości z komponentów
		if unique_data.components != null:
			for comp in unique_data.components:
				if comp is DurabilityComponent:
					item_instance.state["durability"] = comp.max_durability
					break

		(instance as PlacedObject).saved_item_instance = item_instance

func _get_gizmo_color() -> Color:
	return Color.YELLOW

## Rysuje żółty przekreślony kwadrat dla obiektów fizycznych w Edytorze Godota.
func _draw_spawner_icon() -> void:
	var half: float = GIZMO_BOX_HALF_SIZE
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color.YELLOW, false, EDITOR_GIZMO_LINE_WIDTH)
	draw_line(Vector2(-half, -half), Vector2(half, half), Color.YELLOW, EDITOR_GIZMO_LINE_WIDTH)
	draw_line(Vector2(-half, half), Vector2(half, -half), Color.YELLOW, EDITOR_GIZMO_LINE_WIDTH)
