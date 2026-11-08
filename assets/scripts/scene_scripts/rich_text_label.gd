extends RichTextLabel
## Rozszerzony komponent RichTextLabel umożliwiający płynne przewijanie tekstu z poziomu kodu lub pada.

const DEFAULT_SCROLL_STEP_PX: float = 10.0

## Wartość (w pikselach), o jaką przesuwamy tekst przy pojedynczym kroku przewijania.
@export var scroll_step: float = DEFAULT_SCROLL_STEP_PX

func scroll(direction: bool = false) -> void:
	var v_scrollbar: VScrollBar = get_v_scroll_bar()
	if v_scrollbar == null:
		return
	if direction:
		# direction == true -> przewijamy w górę (zmniejszamy wartość)
		v_scrollbar.value -= scroll_step
	else:
		# direction == false -> przewijamy w dół (zwiększamy wartość)
		v_scrollbar.value += scroll_step
