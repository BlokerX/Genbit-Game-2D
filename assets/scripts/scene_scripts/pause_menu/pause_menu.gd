extends CanvasLayer

@export_category("Konfiguracja")
@export var settings_scene: PackedScene # <-- Scena główna ustawień

@onready var background = $Background
@onready var center_container = $CenterContainer
@onready var resume_button = $CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button = $CenterContainer/VBoxContainer/SettingsButton # <-- Nowy przycisk
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

var active_settings_menu: Node = null # Śledzi, czy ustawienia są aktualnie otwarte

func _ready() -> void:
	layer = GameLayers.UI_PAUSE
	
	# Na starcie chowamy menu pauzy
	hide()
	
	# Podłączamy sygnały z przycisków
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	visibility_changed.connect(func():
		# Kiedy menu pauzy staje się widoczne (i ustawienia nie zasłaniają ekranu)
		if visible and not is_instance_valid(active_settings_menu):
			resume_button.grab_focus()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Game_Pause"):
		# --- TARCZA DIALOGOWA ---
		if DialogueManager.is_active:
			return
		
		# Tarcza: Od razu informujemy silnik, że zjedliśmy ten klawisz
		get_viewport().set_input_as_handled()
		
		# --- ZABEZPIECZENIE: Jeśli Ustawienia są otwarte, zamykamy TYLKO ustawienia ---
		if is_instance_valid(active_settings_menu):
			if active_settings_menu.has_method("_on_back_pressed"):
				active_settings_menu._on_back_pressed()
			else:
				active_settings_menu.queue_free()
			return # Przerywamy działanie! Gra nadal zostaje zapauzowana.
		
		# Sprawdzamy obecny stan gry:
		if get_tree().paused:
			# Jeśli gra JEST już zapauzowana -> WZNÓW GRĘ 
			_on_resume_pressed()
		else:
			# Jeśli gra leci normalnie -> ZAPAUZUJ
			_toggle_pause()

func _toggle_pause() -> void:
	# Odwracamy stan pauzy na przeciwny
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	
	# Pokazujemy lub ukrywamy interfejs pauzy
	visible = is_paused
	EventBus.set_menu_state(EventBus.MENU_PAUSE, is_paused)
	
	# --- RĘCZNE WSTRZYMYWANIE MUZYKI ---
	var music_player = get_tree().current_scene.find_child("MusicPlayer", true, false)
	if music_player and music_player is AudioStreamPlayer:
		music_player.stream_paused = is_paused

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_settings_pressed() -> void:
	if settings_scene:
		# 1. Ładujemy scenę ustawień
		active_settings_menu = settings_scene.instantiate()
		add_child(active_settings_menu)
		
		# 2. Estetyka: Chowamy przyciski z Menu Pauzy, żeby nie zrobił się bałagan na ekranie
		center_container.hide()
		
		# 3. Kiedy menu ustawień zostanie zniszczone (gracz wciśnie "Wróć"), przywracamy pauzę
		active_settings_menu.tree_exited.connect(func():
			center_container.show()
			settings_button.grab_focus()
		)
	else:
		push_error("PauseMenu: Brak przypisanej sceny ustawień (settings_scene) w Inspektorze!")

func _on_quit_pressed() -> void:
	# BARDZO WAŻNE: Przed wyjściem do Menu Głównego, MUSIMY odmrozić grę!
	get_tree().paused = false 
	
	# Reset globalnych zmiennych:
	DialogueState.reset_state()
	EventBus.reset()
	
	# Korzystamy z nowego systemu z main.gd, szukając go po grupie
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("to_main_menu"):
		main_node.to_main_menu()
	else:
		push_error("PauseMenu: Nie znaleziono węzła głównego (Main) na drzewie!")
