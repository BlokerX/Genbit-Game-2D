extends Effect
class_name TriggerEffect

func _init():
	effect_name = "Trigger"
	effect_color = Color.ORANGE

func apply_effect(target: Node2D) -> bool:
	# Ten efekt nie modyfikuje zdrowia ani ruchu sam z siebie.
	# Służy tylko jako zapalnik dla obiektów (jak miny czy beczki), 
	# które same zadecydują w receive_effect(), co z tym zrobić.
	return true
