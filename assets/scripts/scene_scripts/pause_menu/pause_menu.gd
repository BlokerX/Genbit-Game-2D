extends CanvasLayer
## Kontroler Menu Pauzy zarządzający wstrzymaniem drzewa gry, muzyki oraz otwieraniem podmenu Ustawień.

@export_category("Konfiguracja")
## Scena główna ustawień otwierana z poziomu pauzy.
@export var settings_scene: PackedScene

@onready var background: CanvasItem = $Background
@onready var center_container: Control = $CenterContainer
@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

## Śledzi, czy okno ustawień jest aktualnie otwarte.
var active_settings_menu: Node = null

func _ready() -> void:
	layer = GameLayers.UI_PAUSE
	hide()

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	visibility_changed.connect(func():
		if visible and not is_instance_valid(active_settings_menu):
			resume_button.grab_focus()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Game_Pause"):
		# --- TARCZA DIALOGOWA ---
		if DialogueManager.is_active:
			return

		get_viewport().set_input_as_handled()

		# --- ZABEZPIECZENIE: Jeśli Ustawienia są otwarte, zamykamy TYLKO ustawienia ---
		if is_instance_valid(active_settings_menu):
			if active_settings_menu.has_method("_on_back_pressed"):
				active_settings_menu.call("_on_back_pressed")
			else:
				active_settings_menu.queue_free()
			return

		if get_tree().paused:
			_on_resume_pressed()
		else:
			_toggle_pause()

func _toggle_pause() -> void:
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused

	visible = is_paused
	EventBus.set_menu_state(EventBus.MENU_PAUSE, is_paused)

	# --- WSTRZYMYWANIE MUZYKI (Zasada Odwrócenia Zależności - DIP) ---
	# Współpracuje zarówno z MusicPlayerManager (Node z właściwością stream_paused), jak i zwykłym AudioStreamPlayer!
	if get_tree().current_scene != null:
		var music_player: Node = get_tree().current_scene.find_child("MusicPlayer", true, false)
		if music_player != null and "stream_paused" in music_player:
			music_player.set("stream_paused", is_paused)

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_settings_pressed() -> void:
	if settings_scene:
		active_settings_menu = settings_scene.instantiate()
		add_child(active_settings_menu)
		center_container.hide()

		active_settings_menu.tree_exited.connect(func():
			center_container.show()
			settings_button.grab_focus()
		)
	else:
		push_error("PauseMenu: Brak przypisanej sceny ustawień (settings_scene) w Inspektorze!")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	var main_node: Node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("to_main_menu"):
		main_node.call("to_main_menu")
	else:
		push_error("PauseMenu: Nie znaleziono węzła głównego (Main) na drzewie!")
