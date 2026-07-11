extends Control

@onready var close_credits_button = $HBoxContainer/CreditsPanel/CreditsVBox/CreditsHeaderPanel/CreditsHeaderHBox/CreditsCloseButton

func _ready() -> void:
	close_credits_button.pressed.connect(credits_close)
	close_credits_button.grab_focus()

func credits_close() -> void:
	get_parent().get_parent().retake_focus()
	self.queue_free()
