extends Node
class_name StoryEventReceiver

@export_group("Oczekiwane Zdarzenie")
## Na jakie hasło z EventBusa ten węzeł ma zareagować?
@export var expected_event_name: String = ""

## Czy zdarzenie ma się wywołać tylko raz (np. otwarcie wrót bossa)?
@export var trigger_only_once: bool = true

@export_group("Reakcja")
## Czas (w sekundach) od usłyszenia hasła do wywołania reakcji (buduje napięcie).
@export var delay_seconds: float = 0.0

## Lista efektów, które zostaną nałożone na rodzica (np. DamageEffect by zniszczyć kolumnę, HealEffect, SpawnObjectEffect).
@export var consequences: Array[Effect] = []

## Ten sygnał połączysz w Edytorze ze skryptem rodzica (np. ze _start_opening() w door.gd)
signal event_received()

var _has_triggered: bool = false

func _ready() -> void:
	if expected_event_name != "":
		EventBus.story_event_triggered.connect(_on_story_event_triggered)

func _on_story_event_triggered(event_name: String) -> void:
	if event_name == expected_event_name:
		if trigger_only_once and _has_triggered:
			return
			
		_has_triggered = true
		
		# Obsługa opóźnienia dla lepszego feelingu
		if delay_seconds > 0.0:
			await get_tree().create_timer(delay_seconds).timeout
			# Zabezpieczenie: sprawdzamy czy obiekt nie został zniszczony w trakcie czekania
			if not is_inside_tree(): return 
			
		_execute_reaction()

func _execute_reaction() -> void:
	# 1. Wyślij sygnał (dla logiki, którą wyklikasz w edytorze)
	event_received.emit()
	
	# 2. Nałóż efekty na rodzica (zgodnie z Twoim systemem ECS)
	var parent = get_parent()
	if parent and parent.has_method("receive_effect"):
		for effect in consequences:
			if effect != null:
				parent.receive_effect(effect.duplicate(true))
