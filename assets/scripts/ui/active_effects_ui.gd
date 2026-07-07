extends VBoxContainer

@export var player: PlayerCharacter

# Słownik do śledzenia aktualnie wyświetlanych ikon efektów (Klucz: nazwa efektu, Wartość: Referencja do VBox'a UI)
var displayed_effects: Dictionary = {}

func _process(_delta: float) -> void:
	if not player or not "effects_collector" in player:
		return
		
	var collector = player.effects_collector
	if not collector:
		return
		
	# Zebranie listy aktualnych nazw efektów na graczu
	var current_effect_names = []
	
	# Pętla po wszystkich dzieciach (efektach) przypiętych do effects_collector
	for child in collector.get_children():
		# _active_effect.gd posiada właściwość 'effect_resource'
		if child.get("effect_resource") != null:
			var res = child.effect_resource
			var eff_name = res.effect_name
			var time_left = child.duration
			current_effect_names.append(eff_name)
			
			# Jeśli efektu nie ma jeszcze w UI, utwórz go
			if not displayed_effects.has(eff_name):
				create_effect_icon(res)
				
			# Zaktualizuj etykietę czasu
			update_effect_time(eff_name, time_left)
			
	# Usuń z UI efekty, których już nie ma na graczu
	var keys_to_remove = []
	for displayed_eff in displayed_effects.keys():
		if not current_effect_names.has(displayed_eff):
			displayed_effects[displayed_eff].queue_free()
			keys_to_remove.append(displayed_eff)
			
	for key in keys_to_remove:
		displayed_effects.erase(key)

func create_effect_icon(effect_resource: Resource) -> void:
	var container = VBoxContainer.new()
	
	var icon = TextureRect.new()
	icon.texture = effect_resource.icon # Używamy tekstury dodanej w kroku 1
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(32, 32)
	
	var time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Zapisujemy referencję do labela w metadanych kontenera, aby łatwo go aktualizować
	container.set_meta("time_label", time_label) 
	
	container.add_child(icon)
	container.add_child(time_label)
	
	add_child(container)
	displayed_effects[effect_resource.effect_name] = container

func update_effect_time(effect_name: String, time_left: float) -> void:
	var container = displayed_effects[effect_name]
	var label = container.get_meta("time_label")
	# Formatujemy czas np. "15s" lub "2.5s" dla krótkich czasów
	if time_left > 10.0:
		label.text = str(int(time_left)) + "s"
	else:
		label.text = "%.1f" % time_left + "s"
