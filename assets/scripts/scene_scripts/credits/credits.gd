extends Control

@onready var button_credits_close = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/CreditsCloseButton
@onready var rich_text_label = $PanelContainer/VBoxContainer/PanelContainer2/RichTextLabel


func _ready() -> void:
	button_credits_close.pressed.connect(credits_close)
	button_credits_close.grab_focus()
	

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_down") and Input.is_action_pressed("ui_up"):
		pass
	elif Input.is_action_pressed("ui_down"):
		rich_text_label.scroll()
	elif Input.is_action_pressed("ui_up"):
		rich_text_label.scroll(true)
	

func credits_close() -> void:
	get_parent().get_parent().back_from_credits()
	self.queue_free()
