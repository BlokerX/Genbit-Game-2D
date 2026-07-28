extends CanvasLayer

@onready var background = $Background
@onready var center_container = $CenterContainer
@onready var resume_button = $CenterContainer/VBoxContainer/ResumeButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# Na starcie chowamy menu pauzy
	hide()
	
	# Podłączamy sygnały z przycisków
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	visibility_changed.connect(func():
		if visible:
			# Kiedy menu pauzy staje się widoczne, automatycznie podświetlamy przycisk "Wznów"
			resume_button.grab_focus()
	)

# Używamy _unhandled_input! Łapie klawisz tylko wtedy, 
# gdy nie został zjedzony przez _input() (np. przez CraftingUI)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Game_Pause"):
		# Tarcza: Od razu informujemy silnik, że zjedliśmy ten klawisz
		get_viewport().set_input_as_handled()
		
		# Sprawdzamy obecny stan gry:
		if get_tree().paused:
			# Jeśli gra JEST już zapauzowana -> WZNÓW GRĘ (Symulujemy kliknięcie przycisku)
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

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_quit_pressed() -> void:
	# BARDZO WAŻNE: Przed wyjściem do Menu Głównego, MUSIMY odmrozić grę!
	get_tree().paused = false 
	
	# Korzystamy z nowego systemu z main.gd, szukając go po grupie
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("to_main_menu"):
		main_node.to_main_menu()
	else:
		push_error("PauseMenu: Nie znaleziono węzła głównego (Main) na drzewie!")
