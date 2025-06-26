extends Control

@onready var button_credits_close = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/CreditsCloseButton

func _ready() -> void:
	button_credits_close.pressed.connect(credits_close)

func credits_close() -> void:
	self.queue_free()
