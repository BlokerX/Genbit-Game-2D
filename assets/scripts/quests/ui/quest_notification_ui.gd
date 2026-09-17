extends CanvasLayer
class_name QuestNotificationUI

@export_group("Ustawienia Animacji (Wjazd z góry)")
## Czas, przez który baner zostaje na ekranie (w sekundach)
@export var display_duration: float = 4
## Czas trwania samej animacji wjazdu/zjazdu (w sekundach)
@export var slide_duration: float = 0.4
## Pozycja początkowa i końcowa w osi Y (np. -80 pikseli to wyjazd poza górną krawędź ekranu)
@export var off_screen_y: float = -80.0
## Miejsce, do którego wjeżdża baner (np. 20 pikseli od góry ekranu)
@export var on_screen_y: float = 20.0
## Jak bardzo przyspieszyć animację, gdy w kolejce czekają inne powiadomienia? (3.0 = 3x szybciej)
@export var rush_speed_multiplier: float = 4

@onready var container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var quest_name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/QuestNameLabel

var _queue: Array[Dictionary] = []
var _is_animating: bool = false

# --- NOWOŚĆ: Przechowujemy referencję do aktualnej animacji ---
var _active_tween: Tween 

func _ready() -> void:
	layer = 60 # Warstwa wysoko, żeby była nad dziennikiem!
	process_mode = Node.PROCESS_MODE_ALWAYS 
	container.modulate.a = 0.0
	
	# Twarde wymuszenie niewidoczności na starcie
	hide()
	
	QuestManager.quest_started.connect(func(q): _queue_notification("NOWE ZADANIE", q.title, Color(1, 0.8, 0.2)))
	QuestManager.quest_updated.connect(func(q, _s): _queue_notification("ZAKTUALIZOWANO ZADANIE", q.title, Color(0.6, 0.8, 1)))
	QuestManager.quest_completed.connect(func(q): _queue_notification("ZADANIE UKOŃCZONE", q.title, Color(0.4, 0.9, 0.4)))
	QuestManager.quest_failed.connect(func(q): _queue_notification("ZADANIE OBLANE", q.title, Color(0.9, 0.3, 0.3)))

func _queue_notification(title: String, quest_name: String, color: Color) -> void:
	_queue.append({"title": title, "name": quest_name, "color": color})
	
	if not _is_animating:
		_process_queue()
	elif _active_tween and _active_tween.is_valid():
		# --- ROZWIĄZANIE AAA: DYNAMICZNE PRZYSPIESZENIE Z INSPEKTORA ---
		# Jeśli dodajemy nowe powiadomienie, a inne już wisi na ekranie,
		# drastycznie przyspieszamy aktualną animację używając naszej zmiennej!
		_active_tween.set_speed_scale(rush_speed_multiplier)

func _process_queue() -> void:
	if _queue.is_empty():
		_is_animating = false
		hide() # Twarde ukrycie całego CanvasLayera gdy skończymy wyświetlać pop-upy
		return
		
	show() # Twarde pokazanie CanvasLayera zanim zaczniemy animację
	_is_animating = true
	var data = _queue.pop_front()
	
	title_label.text = data["title"]
	title_label.add_theme_color_override("font_color", data["color"])
	quest_name_label.text = data["name"]
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	# Jeśli z jakiegoś powodu kolejka po zdjęciu naszego powiadomienia NADAL ma w sobie inne elementy,
	# od razu ustawiamy tempo na szybkie. Jeśli nie - normalne x1.0.
	if _queue.size() > 0:
		_active_tween.set_speed_scale(rush_speed_multiplier)
	else:
		_active_tween.set_speed_scale(1.0)
	
	# 1. Animacja wjazdu
	container.position.y = off_screen_y
	_active_tween.tween_property(container, "modulate:a", 1.0, slide_duration)
	_active_tween.parallel().tween_property(container, "position:y", on_screen_y, slide_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Czekanie (jeśli animacja została przyspieszona wyżej, czas czekania proporcjonalnie się zmniejszy)
	_active_tween.tween_interval(display_duration)
	
	# 3. Animacja zjazdu
	_active_tween.tween_property(container, "modulate:a", 0.0, slide_duration)
	_active_tween.parallel().tween_property(container, "position:y", off_screen_y, slide_duration).set_ease(Tween.EASE_IN)
	
	_active_tween.finished.connect(_process_queue)
