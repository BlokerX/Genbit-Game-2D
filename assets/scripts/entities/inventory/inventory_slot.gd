# inventory_slot.gd
extends PanelContainer

@onready var icon_rect: TextureRect = $TextureRect

func update_slot(item: ItemData) -> void:
	if item:
		icon_rect.texture = item.icon
		icon_rect.show()
	else:
		icon_rect.texture = null
		icon_rect.hide()
