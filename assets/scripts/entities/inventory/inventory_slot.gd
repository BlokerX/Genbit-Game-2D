# inventory_slot.gd
extends TextureRect
class_name InventorySlot

@export_group("Slot Textures")
## Tekstura zwykłego, niewybranego slotu
@export var texture_normal: Texture2D
## Tekstura aktywnego (wybranego) slotu
@export var texture_highlighted: Texture2D

@onready var icon_rect: TextureRect = $Item
# Pobieramy nasz nowy węzeł z cyferką
@onready var amount_label: Label = $AmountLabel

func update_slot(slot: SlotData) -> void:
	if slot and not slot.is_empty():
		icon_rect.texture = slot.item_data.item_icon
		icon_rect.show()
		# Wyświetlamy ilość tylko wtedy, gdy jest więcej niż 1 sztuka
		# (zazwyczaj nie chcemy widzieć "1" na pojedynczym mieczu)
		if slot.stack_amount > 1:
			amount_label.text = str(slot.stack_amount)
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
