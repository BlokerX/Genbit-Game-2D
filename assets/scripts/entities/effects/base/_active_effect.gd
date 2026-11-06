extends Node
class_name ActiveEffect

signal effect_ended(effect_resource) # Sygnał zakończenia

var target : Node2D
var tick_interval : float
var duration : float
var is_infinite : bool = false
var effect_resource : Resource # Przechowuje referencję do zasobu, który go stworzył
var _tick_timer : float = 0.0
var _is_started : bool = false
var _is_ended : bool = false

## Inicjalizacja zmiennych węzła (może być wywołana przed add_child, by UI od razu widziało dane)
func setup(_target: Node2D, _effect: Resource, _duration: float, _tick_interval: float, _is_infinite: bool = false) -> void:
	target = _target
	effect_resource = _effect
	duration = _duration
	tick_interval = _tick_interval
	is_infinite = _is_infinite
	_tick_timer = tick_interval

func _ready() -> void:
	if not _is_started and is_instance_valid(target) and effect_resource != null:
		_is_started = true
		# Wywołanie akcji startowej (np. nałożenie spowolnienia)
		effect_resource.on_effect_start(target)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	# Odliczamy czas tylko, jeśli efekt NIE jest nieskończony
	if not is_infinite:
		duration -= delta
		if duration <= 0:
			end_effect()
			return

	# Odliczanie do kolejnego "tiku" (np. uderzenia trucizny)
	if tick_interval > 0:
		_tick_timer -= delta
		if _tick_timer <= 0:
			effect_resource.on_effect_tick(target)
			_tick_timer = tick_interval # Zresetuj stoper tiku

func end_effect() -> void:
	if _is_ended:
		return
	_is_ended = true
	set_process(false)
	# Wywołanie akcji końcowej (np. zdjęcie spowolnienia)
	if is_instance_valid(target) and effect_resource != null:
		effect_resource.on_effect_end(target)
	effect_ended.emit(effect_resource) # Wysyłamy sygnał przed usunięciem
	queue_free() # Usuń ten węzeł z drzewa sceny
