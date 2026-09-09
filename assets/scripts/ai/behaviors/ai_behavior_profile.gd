extends Resource
class_name AIBehaviorProfile

@export_category("Percepcja i Dystans")
@export var detection_distance: float = 600.0
@export var min_stopping_distance: float = 30.0

@export_category("Poruszanie")
@export var can_rotate_to_target: bool = true # NOWOŚĆ: decyduje czy wróg się obraca!
@export var rotation_speed: float = 5.0
@export var wander_radius: float = 150.0
@export var wander_interval_min: float = 1.0
@export var wander_interval_max: float = 6.0
