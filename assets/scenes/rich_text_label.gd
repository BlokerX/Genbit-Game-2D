extends RichTextLabel

## Amount of units the scroll will scroll thru when [method scroll] is called.
@export_range(0.0,100.0,0.1) var scroll_step: float = 10.0

func _physics_process(_delta: float) -> void:
	var direction:int = Input.get_axis("Down","Up")
	scroll(direction)

func scroll(direction: int = 1) -> void:
	var v_scrollbar = get_v_scroll_bar()
	v_scrollbar.value -= scroll_step * direction
