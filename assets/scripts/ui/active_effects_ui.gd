extends VBoxContainer

@export var player: PlayerCharacter

# Pobieramy bezpośrednią referencję do Twojego napisu z drzewa sceny
@onready var effects_label: Label = $EffectsLabel

# Słownik do śledzenia aktualnie wyświetlanych ikon efektów (Klucz: nazwa efektu, Wartość: Referencja do kontenera UI)
var displayed_effects: Dictionary = {}

func _process(_delta: float) -> void:
	# Jeśli nie ma gracza, upewniamy się, że label jest ukryty
	if not player or not "effects_collector" in player:
		if effects_label: effects_label.visible = false
		return
		
	var collector = player.effects_collector
	if not collector:
		if effects_label: effects_label.visible = false
		return
		
	# Zebranie listy aktualnych nazw efektów na graczu
	var current_effect_names = []
	
	# Pętla po wszystkich dzieciach (efektach) przypiętych do effects_collector
	for child in collector.get_children():
		if child.get("effect_resource") != null:
			var res = child.effect_resource
			var eff_name = res.effect_name
			var time_left = child.duration
			var _is_inf = child.is_infinite # <--- POBIERAMY FLAGĘ
			current_effect_names.append(eff_name)
			
			# Jeśli efektu nie ma jeszcze w UI, utwórz go
			if not displayed_effects.has(eff_name):
				create_effect_icon(res)
				
			# Zaktualizuj etykietę czasu (dodajemy nowy argument)
			update_effect_time(eff_name, time_left, _is_inf)
			
	# Usuń z UI efekty, których już nie ma na graczu
	var keys_to_remove = []
	for displayed_eff in displayed_effects.keys():
		if not current_effect_names.has(displayed_eff):
			displayed_effects[displayed_eff].queue_free()
			keys_to_remove.append(displayed_eff)
			
	for key in keys_to_remove:
		displayed_effects.erase(key)
		
	# --- TUTAJ STERUJEMY WIDOCZNOŚCIĄ NAPISU ---
	# Jeśli słownik efektów jest pusty -> false (ukrywa). Jeśli ma coś w sobie -> true (pokazuje).
	if effects_label:
		effects_label.visible = not displayed_effects.is_empty()

func create_effect_icon(effect_resource: Resource) -> void:
	var container: Container
	var has_icon = effect_resource.get("icon") != null
	
	# Pobieramy kolor z zasobu (lub używamy białego jako zabezpieczenia, jeśli brakuje właściwości)
	var effect_color: Color = Color.WHITE
	if effect_resource.get("effect_color") != null:
		effect_color = effect_resource.effect_color
	
	if has_icon:
		# VBoxContainer układa elementy pionowo (ikona, a pod nią czas)
		container = VBoxContainer.new()
		
		var icon = TextureRect.new()
		icon.texture = effect_resource.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(32, 32)
		container.add_child(icon)
	else:
		# HBoxContainer układa elementy poziomo (nazwa, a obok czas)
		container = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = effect_resource.effect_name + ": "
		# Nadpisujemy kolor napisu nazwy
		name_label.add_theme_color_override("font_color", effect_color)
		container.add_child(name_label)
	
	var time_label = Label.new()
	# Nadpisujemy kolor napisu czasu
	time_label.add_theme_color_override("font_color", effect_color)
	
	if has_icon:
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	# Zapisujemy referencję do labela w metadanych kontenera
	container.set_meta("time_label", time_label) 
	
	container.add_child(time_label)
	
	add_child(container)
	displayed_effects[effect_resource.effect_name] = container

func update_effect_time(effect_name: String, time_left: float, is_infinite: bool) -> void:
	var container = displayed_effects[effect_name]
	var label = container.get_meta("time_label")
	
	# --- NOWOŚĆ: Wyświetlanie nieskończoności ---
	if is_infinite:
		label.text = "∞"
		return # Przerywamy funkcję, nie formatujemy czasu
		
	# Formatujemy czas dla standardowych efektów
	if time_left > 10.0:
		label.text = str(int(time_left)) + "s"
	else:
		label.text = "%.1f" % time_left + "s"
