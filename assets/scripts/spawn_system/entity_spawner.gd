@tool
extends BaseWorldSpawner
## Zaawansowany spawner obiektów (przeciwników, jednostek AI).
## Reaguje na ładowanie chunków (Open World), dystans gracza, sygnały fabularne lub komendy Reżysera.
class_name EntitySpawner

const GIZMO_CIRCLE_RADIUS: float = 16.0
const GIZMO_CROSS_HALF_SIZE: float = 8.0
const GIZMO_CIRCLE_SEGMENTS: int = 16

@export_group("Konfiguracja Spawnu")
## Zasób, z którego spawner powoła obiekt. 
## Może to być bezpośrednia scena (PackedScene) LUB Pula (EnemySpawnPool).
@export var spawn_resource: Resource

## Sprawdza, czy przypisano zasób przeciwnika do zespawnowania.
func _has_valid_spawn_configuration() -> bool:
	return spawn_resource != null

## Rozpoznaje typ podpiętego zasobu (Scena czy Pula) i tworzy instancję przeciwnika.
func _create_spawn_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	var spawned_node: Node = _create_instance()
	if spawned_node != null:
		nodes.append(spawned_node)
	return nodes

func _create_instance() -> Node:
	if spawn_resource is PackedScene:
		return (spawn_resource as PackedScene).instantiate()
	elif spawn_resource != null and spawn_resource.has_method("get_random_enemy_scene"):
		var scene: PackedScene = spawn_resource.call("get_random_enemy_scene") as PackedScene
		return scene.instantiate() if scene != null else null
	return null

func _get_gizmo_color() -> Color:
	return Color.FUCHSIA

## Rysowanie różowego celownika w Edytorze Godota (niewidoczne w grze).
func _draw_spawner_icon() -> void:
	draw_arc(Vector2.ZERO, GIZMO_CIRCLE_RADIUS, 0.0, TAU, GIZMO_CIRCLE_SEGMENTS, Color.FUCHSIA, EDITOR_GIZMO_LINE_WIDTH)
	draw_line(Vector2(-GIZMO_CROSS_HALF_SIZE, 0.0), Vector2(GIZMO_CROSS_HALF_SIZE, 0.0), Color.FUCHSIA, EDITOR_GIZMO_LINE_WIDTH)
	draw_line(Vector2(0.0, -GIZMO_CROSS_HALF_SIZE), Vector2(0.0, GIZMO_CROSS_HALF_SIZE), Color.FUCHSIA, EDITOR_GIZMO_LINE_WIDTH)
