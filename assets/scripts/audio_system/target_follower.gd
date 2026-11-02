extends Node
class_name TargetFollower

var target: Node2D
var visual_node: Node2D
var offset: Vector2 = Vector2.ZERO

func setup(_visual_node: Node2D, _target: Node2D, _offset: Vector2 = Vector2.ZERO) -> void:
	visual_node = _visual_node
	target = _target
	offset = _offset
	set_process(true)

func _process(_delta: float) -> void:
	if is_instance_valid(target) and is_instance_valid(visual_node):
		visual_node.global_position = target.global_position + offset
	else:
		# Gdy cel zginie lub zniknie, odpinamy śledzenie. 
		set_process(false)
		queue_free()
