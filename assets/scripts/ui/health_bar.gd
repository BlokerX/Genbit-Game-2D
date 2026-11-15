extends ProgressBar
class_name HealthBar
## Pasek zdrowia obsługujący automatyczne wykrywanie opcjonalnej etykiety tekstowej (Label),
## spójną stylizację wizualną oraz synchronizację z zasobem LifeStatsComponent / MonitoredLifeStatsComponent.

@export var character_entity: CharacterEntity

## Opcjonalna etykieta tekstowa wyszukiwana automatycznie wśród dzieci paska.
var health_points_label: Label = null

func _ready() -> void:
	# 1. AUTOMATYCZNE SZUKANIE: Skrypt szuka w swoich dzieciach węzła typu Label
	for child in get_children():
		if child is Label:
			health_points_label = child as Label
			break

	# Polimorficzna stylizacja głównego paska HUD gracza (SOLID - OCP / LSP, brak sprawdzania podklas przez 'is')
	if _should_apply_hud_styling():
		UIThemeStyler.apply_progress_bar_style(self, UIThemeStyler.HP_BAR_FILL_COLOR)
		if health_points_label != null:
			UIThemeStyler.apply_readable_label_style(health_points_label)

	# 2. Podłączenie do zasobu zdrowia
	if character_entity != null and character_entity.health_stats_script != null:
		var stats: LifeStatsComponent = character_entity.health_stats_script

		if not stats.health_changed.is_connected(_on_health_updated):
			stats.health_changed.connect(_on_health_updated)
		if stats.has_signal("max_health_changed") and not stats.is_connected("max_health_changed", _on_max_health_changed):
			stats.connect("max_health_changed", _on_max_health_changed)

		_on_max_health_changed(stats.max_health)
		_on_health_updated(stats.health, stats.max_health)

## Określa, czy pasek ma przyjąć pełną stylizację kafelka HUD (nadpisywane w paskach jednostek na mapie - OCP).
func _should_apply_hud_styling() -> bool:
	return true

## Reakcja na sygnał zmiany aktualnego HP.
func _on_health_updated(current_health: int, maximum_health: int) -> void:
	self.max_value = maximum_health
	self.value = current_health
	if health_points_label != null:
		health_points_label.text = str(current_health) + " / " + str(maximum_health)

## Reakcja na sygnał zwiększenia/zmniejszenia maksymalnego HP.
func _on_max_health_changed(new_max_health: int) -> void:
	self.max_value = new_max_health
