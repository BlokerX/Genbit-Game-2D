# inventory_slot.gd
extends TextureRect
class_name InventorySlot

@onready var icon_rect: TextureRect = $Item
var texture_normal = preload("res://assets/textures/samples_examples/inventory_slot.png")
var texture_highlighted = preload("res://assets/textures/samples_examples/inventory_active_slot.png")
# Pobieramy nasz nowy węzeł z cyferką
@onready var amount_label: Label = $AmountLabel

func update_slot(item: ItemData) -> void:
	if item:
		icon_rect.texture = item.item_icon
		icon_rect.show()
		# Wyświetlamy ilość tylko wtedy, gdy jest więcej niż 1 sztuka
		# (zazwyczaj nie chcemy widzieć "1" na pojedynczym mieczu)
		if item.item_stack_count > 1:
			amount_label.text = str(item.item_stack_count)
			amount_label.show()
		else:
			amount_label.hide()
	else:
		# Jeśli slot jest pusty, ukrywamy i ikonę, i cyferkę
		icon_rect.texture = null
		icon_rect.hide()
		amount_label.hide()

# Funkcja zmieniająca teksturę w zależności od stanu
func set_highlight(is_active: bool) -> void:
	if is_active:
		# Jeśli slot jest wybrany, dajemy podświetloną teksturę
		texture = texture_highlighted
	else:
		# Jeśli nie jest wybrany, wracamy do zwykłej tekstury
		texture = texture_normal
