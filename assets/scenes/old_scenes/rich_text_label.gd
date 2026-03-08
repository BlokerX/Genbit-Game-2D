extends RichTextLabel

# Wartość o jaką przesuwamy tekst (możesz dostosować w Inspektorze)
var scroll_step: float = 10.0

func scroll(direction: bool = false) -> void:
	# Pobieramy referencję do pionowego paska przewijania
	var v_scrollbar = get_v_scroll_bar()
	
	if direction:
		# direction == true -> przewijamy w górę (zmniejszamy wartość)
		v_scrollbar.value -= scroll_step
	else:
		# direction == false -> przewijamy w dół (zwiększamy wartość)
		v_scrollbar.value += scroll_step
