extends Node
class_name ActiveEffect

signal effect_ended(effect_resource) # Sygnał zakończenia

var target : CharacterBody2D
var tick_interval : float
var duration : float
var effect_resource : Resource # Przechowuje referencję do zasobu, który go stworzył

var _tick_timer : float = 0.0

# Inicjalizacja węzła
func setup(_target: CharacterBody2D, _effect: Resource, _duration: float, _tick_interval: float) -> void:
	target = _target
	effect_resource = _effect
	duration = _duration
	tick_interval = _tick_interval
	_tick_timer = tick_interval
	
	# Wywołanie akcji startowej (np. nałożenie spowolnienia)
	effect_resource.on_effect_start(target)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	
	# Odliczanie ogólnego czasu trwania efektu
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
	# Wywołanie akcji końcowej (np. zdjęcie spowolnienia)
	effect_resource.on_effect_end(target)
	effect_ended.emit(effect_resource) # Wysyłamy sygnał przed usunięciem
	queue_free() # Usuń ten węzeł z drzewa sceny
