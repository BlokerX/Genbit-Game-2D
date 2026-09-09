extends EnemyEntity
class_name NewEnemySpider

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
var wanderTimer: float = 0.0 

func _ready():
	if ai_controller == null:
		ai_controller = get_node_or_null("AIController")
	super()

func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target

# CAŁA RESZTA ZOSTAŁA PRZEJĘTA PRZEZ AI!
