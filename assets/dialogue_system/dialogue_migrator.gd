@tool
extends EditorScript

# Słownik do zapobiegania nieskończonym pętlom i powielaniu węzłów
# Klucz: stary zasób DialogueLine, Wartość: StringName (nowe ID)
var visited_lines: Dictionary = {}
var graph: DialogueGraph
var node_counter: int = 0

func _run() -> void:
	# 1. ZMIEŃ TE ŚCIEŻKI na własne!
	var source_path = "res://assets/dialogue_system/data/dialogues/lines/test_dialogue_line.tres"
	var dest_path = "res://assets/dialogue_system/data/dialogues/test_dialogue_graph.tres"
	
	print("--- ROZPOCZYNAM MIGRACJĘ DIALOGU ---")
	
	# Ładujemy stary zasób (drzewo)
	var start_line = load(source_path)
	if not start_line:
		printerr("Nie udało się załadować: ", source_path)
		return
		
	graph = DialogueGraph.new()
	visited_lines.clear()
	node_counter = 0
	
	# Odpalamy magię rekurencji!
	var start_id = process_line(start_line)
	graph.start_node_id = start_id
	
	# Zapisujemy nowy zasób grafu do pliku
	var err = ResourceSaver.save(graph, dest_path)
	if err == OK:
		print("Sukces! Zapisano zmigrowany graf do: ", dest_path)
		print("Liczba wygenerowanych węzłów: ", graph.nodes.size())
	else:
		printerr("Błąd podczas zapisu pliku: ", err)

func process_line(line) -> StringName:
	# Zabezpieczenie przed pustymi połączeniami
	if line == null:
		return &""
		
	# Jeśli linia była już przetworzona, ZWRACAMY TYLKO JEJ ID.
	# TO TWORZY BEZPIECZNE CYKLE W GRAFIE!
	if visited_lines.has(line):
		return visited_lines[line]
		
	# Tworzymy nowe unikalne ID dla tego węzła
	node_counter += 1
	var new_id = StringName("node_%03d" % node_counter)
	visited_lines[line] = new_id # Rejestrujemy natychmiast
	
	# Tworzymy i mapujemy nowy DialogueNode
	var new_node = DialogueNode.new()
	new_node.id = new_id
	
	# Bezpieczne kopiowanie starych właściwości (na podstawie Twojego starego DialogueLine)
	if "speaker" in line: new_node.speaker = line.speaker
	if "min_skip_time" in line: new_node.min_skip_time = line.min_skip_time
	if "dialogue_text" in line: new_node.dialogue_text = line.dialogue_text
	if "allow_cancel" in line: new_node.allow_cancel = line.allow_cancel
	
	# Zapisujemy node'a w słowniku głównego grafu
	graph.nodes[new_id] = new_node
	
	var outputs: Array[DialogueConnection] = []
	
	# SCENARIUSZ 1: Linia ma zdefiniowane opcje wyboru
	if "choices" in line and line.choices != null and line.choices.size() > 0:
		for choice in line.choices:
			if choice == null: continue
			
			var conn = DialogueConnection.new()
			if "choice_text" in choice: conn.text = choice.choice_text
			if "choice_icon" in choice: conn.choice_icon = choice.choice_icon
			if "log_choice" in choice: conn.log_choice = choice.log_choice
			if "custom_speaker" in choice: conn.custom_speaker = choice.custom_speaker
			
			# Tablice conditions/consequences kopiujemy płytko (aby zachować wskaźniki do .tres efektów)
			if "conditions" in choice and choice.conditions != null:
				conn.conditions = choice.conditions.duplicate()
			if "consequences" in choice and choice.consequences != null:
				conn.consequences = choice.consequences.duplicate()
				
			# Szukamy dokąd prowadzi ten wybór i wyciągamy jego ID (Rekurencja)
			if "next_line" in choice:
				conn.target_id = process_line(choice.next_line)
				
			outputs.append(conn)
			
	# SCENARIUSZ 2: Automatyczne płynne przejście (bez opcji wyboru)
	elif "next_line" in line and line.next_line != null:
		var auto_conn = DialogueConnection.new()
		auto_conn.text = "" # Pusty tekst oznacza ukryte, automatyczne przejście
		auto_conn.target_id = process_line(line.next_line)
		outputs.append(auto_conn)
		
	new_node.outputs = outputs
	return new_id
