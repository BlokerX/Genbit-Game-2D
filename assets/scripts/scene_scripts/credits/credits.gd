extends Control
## Kontroler ekranu Twórców (Credits) obsługujący przewijanie tekstu i bezpieczny powrót do menu głównego.

@onready var button_credits_close: Button = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/CreditsCloseButton
@onready var rich_text_label: RichTextLabel = $PanelContainer/VBoxContainer/PanelContainer2/RichTextLabel

func _ready() -> void:
	button_credits_close.pressed.connect(credits_close)
	button_credits_close.grab_focus()

func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("ui_down") and Input.is_action_pressed("ui_up"):
		pass
	elif Input.is_action_pressed("ui_down"):
		rich_text_label.scroll()
	elif Input.is_action_pressed("ui_up"):
		rich_text_label.scroll(true)

func credits_close() -> void:
	# Bezpieczne wyszukiwanie właściciela menu w górę hierarchii (DIP - brak sztywnego get_parent().get_parent()!)
	var host: Node = _find_credits_host()
	if host != null:
		host.call("back_from_credits")
	self.queue_free()

func _find_credits_host() -> Node:
	var curr: Node = get_parent()
	while curr != null:
		if curr.has_method("back_from_credits"):
			return curr
		curr = curr.get_parent()
	return null
