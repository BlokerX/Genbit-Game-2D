class_name DurabilityComponent
extends ItemComponent
## Nadaje przedmiotowi ograniczoną wytrzymałość (zużycie przy atakach lub akcjach).

const DEFAULT_MAX_DURABILITY: int = 1
const PERCENT_MULTIPLIER: float = 100.0

@export var max_durability: int = DEFAULT_MAX_DURABILITY

## Ustawiamy domyślną wytrzymałość na maksymalną przy tworzeniu przedmiotu.
func initialize_state(item_instance: ItemInstance) -> void:
	if not item_instance.state.has("durability"):
		item_instance.state["durability"] = max_durability

func get_tooltip_info(item_instance: ItemInstance) -> String:
	if item_instance == null:
		return ""
	var cur_dur: int = item_instance.state.get("durability", max_durability)
	return "Wytrzymałość: " + str(cur_dur) + " / " + str(max_durability) + "\n"

func get_hud_info(item_instance: ItemInstance, is_advanced: bool) -> String:
	if item_instance == null:
		return ""
	var cur_dur: int = item_instance.state.get("durability", max_durability)
	if is_advanced:
		return "Wytrzymałość: " + str(cur_dur) + " / " + str(max_durability) + " HP\n"
	var safe_max: float = maxf(1.0, float(max_durability))
	var pct: int = int((float(cur_dur) / safe_max) * PERCENT_MULTIPLIER)
	return "Stan Przedmiotu: " + str(pct) + "%\n"
