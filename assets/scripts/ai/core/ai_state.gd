extends Node
class_name AIState

var controller: AIController
var blackboard: AIBlackboard

## Wywoływane przez State Machine podczas inicjalizacji.
func initialize(ai_controller: AIController) -> void:
	controller = ai_controller
	blackboard = controller.blackboard

## Odpalane przy wejściu w ten stan.
func enter() -> void:
	pass

## Odpalane przy wyjściu z tego stanu.
func exit() -> void:
	pass

## Logika wykonywana co klatkę, gdy stan jest aktywny.
func physics_process(_delta: float) -> void:
	pass
