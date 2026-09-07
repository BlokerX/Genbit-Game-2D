@tool
extends GraphEdit

var current_file_path: String = ""
var render_generation: int = 0
var _render_queued: bool = false
var _resource_to_render: Resource = null
var file_dialog: EditorFileDialog

var _refresh_queued: bool = false
var _is_typing: bool = false
var _pending_node_positions: Dictionary = {}
var _clipboard_nodes: Array = []

var context_menu: PopupMenu

func _ready() -> void:
	right_disconnects = true 
	
	# --- SYGNAŁY GRAFU ---
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	
	connection_to_empty.connect(_on_connection_to_empty)
	popup_request.connect(_on_popup_request)
	
	# --- SYGNAŁY KOPIOWANIA I WKLEJANIA ---
	copy_nodes_request.connect(_on_copy_nodes_request)
	paste_nodes_request.connect(_on_paste_nodes_request)
	duplicate_nodes_request.connect(_on_duplicate_nodes_request)

	# --- MENU KONTEKSTOWE ---
	context_menu = PopupMenu.new()
	context_menu.add_item("➕ Dodaj Węzeł", 0)
	context_menu.add_item("📋 Wklej", 1)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(context_menu)

	# --- GÓRNY PASEK NARZĘDZI ---
	var toolbar = get_menu_hbox()
	
	var load_btn = Button.new()
	load_btn.text = "📂 Wczytaj Graf"
	load_btn.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_btn)
	toolbar.move_child(load_btn, 0)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "🔄 Odśwież Graf"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_btn)
	toolbar.move_child(refresh_btn, 1)
	
	var edit_graph_btn = Button.new()
	edit_graph_btn.text = "⚙️ Właściwości Grafu"
	edit_graph_btn.pressed.connect(_on_edit_graph_pressed)
	toolbar.add_child(edit_graph_btn)
	toolbar.move_child(edit_graph_btn, 2)

	var save_btn = Button.new()
	save_btn.text = "💾 Zapisz Układ"
	save_btn.pressed.connect(_save_layout)
	toolbar.add_child(save_btn)
	toolbar.move_child(save_btn, 3)

	var arrange_btn = Button.new()
	arrange_btn.text = "✨ Auto-Rozmieść"
	arrange_btn.pressed.connect(arrange_nodes)
	toolbar.add_child(arrange_btn)
	toolbar.move_child(arrange_btn, 4)

	var sep = VSeparator.new()
	toolbar.add_child(sep)
	toolbar.move_child(sep, 5)

	var info_lbl = Label.new()
	info_lbl.text = " Tryb Edycji (Skróty: Ctrl+C, Ctrl+V, Ctrl+D) "
	info_lbl.modulate = Color(0.7, 1.0, 0.7)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.clip_text = true
	toolbar.add_child(info_lbl)
	toolbar.move_child(info_lbl, 6)

	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tres", "Dialogue Resource")
	file_dialog.file_selected.connect(_on_file_selected)
	EditorInterface.get_base_control().add_child(file_dialog)

# --- OBSŁUGA PLIKÓW ---
func _on_load_pressed() -> void:
	file_dialog.popup_centered_ratio(0.5)

func _on_file_selected(path: String) -> void:
	var res = load(path)
	if res:
		load_from_inspector(res)
	else:
		printerr("Dialogue Editor: Nie można wczytać pliku.")

func load_from_inspector(graph: Resource) -> void:
	if not graph: return
	if graph.resource_path != "" and not "::" in graph.resource_path:
		current_file_path = graph.resource_path
		_resource_to_render = graph
		if not _render_queued:
			_render_queued = true
			call_deferred("_do_render")

func _on_refresh_pressed() -> void:
	if current_file_path != "":
		_save_layout()
		load_from_inspector(_resource_to_render)

# --- REAKCJA NA ZMIANY Z INSPEKTORA ---
func _on_node_resource_changed() -> void:
	if _is_typing: return 
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_execute_refresh")

func _execute_refresh() -> void:
	_refresh_queued = false
	_save_layout() 
	_do_render()

# --- RYSOWANIE GRAFU ---
func _do_render() -> void:
	_render_queued = false
	if not _resource_to_render: return
		
	var graph = _resource_to_render
	render_generation += 1
	clear_connections()

	for child in get_children():
		if child is GraphNode or child is Label:
			if child.has_meta("dialogue_node_resource"):
				var res = child.get_meta("dialogue_node_resource")
				if res and res.changed.is_connected(_on_node_resource_changed):
					res.changed.disconnect(_on_node_resource_changed)
			remove_child(child)
			child.queue_free()

	await get_tree().process_frame

	var nodes_dict = graph.get("nodes")
	if nodes_dict == null or typeof(nodes_dict) != TYPE_DICTIONARY:
		return

	var start_id = str(graph.get("start_node_id"))
	var fallback_index = 0

	# ETAP 1: Generowanie Węzłów
	for node_id in nodes_dict:
		var d_node = nodes_dict[node_id]
		if not d_node: continue

		if not d_node.changed.is_connected(_on_node_resource_changed):
			d_node.changed.connect(_on_node_resource_changed)

		var g_node = GraphNode.new()
		var n_id_str = str(node_id)
		g_node.name = n_id_str + "_" + str(render_generation)
		g_node.set_meta("base_name", n_id_str)
		g_node.set_meta("dialogue_node_resource", d_node)
		g_node.resizable = true
		g_node.resize_request.connect(func(new_size): g_node.size = new_size)
		
		g_node.node_selected.connect(func(): EditorInterface.edit_resource(d_node))

		var grid_x = (fallback_index % 3) * 480
		var grid_y = int(fallback_index / 3) * 350
		g_node.position_offset = Vector2(grid_x, grid_y)
		fallback_index += 1

		var is_start = (n_id_str == start_id)
		var title_str = "⭐ START: " + n_id_str if is_start else "📄 " + n_id_str
		
		g_node.title = title_str
		if is_start: g_node.self_modulate = Color(0.6, 1.0, 0.6) 

		var child_idx = 0
		
		# --- SLOT 0: NAGŁÓWEK (Edycja ID i Szybkie Usuwanie) ---
		var top_hbox = HBoxContainer.new()
		
		var id_lbl = Label.new()
		id_lbl.text = "ID:"
		id_lbl.modulate = Color(0.6, 0.6, 0.6)
		top_hbox.add_child(id_lbl)
		
		var id_edit = LineEdit.new()
		id_edit.text = n_id_str
		id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_edit.focus_entered.connect(func(): _is_typing = true)
		id_edit.focus_exited.connect(func():
			_is_typing = false
			var new_id = id_edit.text.strip_edges()
			if new_id != n_id_str and new_id != "" and not nodes_dict.has(StringName(new_id)):
				# Proces bezpiecznej zmiany ID węzła
				var old_id = StringName(n_id_str)
				var new_id_sn = StringName(new_id)
				d_node.set("id", new_id_sn)
				nodes_dict[new_id_sn] = d_node
				nodes_dict.erase(old_id)
				
				if graph.get("start_node_id") == old_id:
					graph.set("start_node_id", new_id_sn)
					
				# Aktualizacja wszystkich połączeń prowadzących do starego ID
				for other_id in nodes_dict:
					var other_node = nodes_dict[other_id]
					var outputs = other_node.get("outputs")
					if outputs:
						for conn in outputs:
							if conn and conn.get("target_id") == old_id:
								conn.set("target_id", new_id_sn)
				ResourceSaver.save(graph, current_file_path)
				_on_refresh_pressed()
			elif new_id == n_id_str:
				pass # Nic się nie zmieniło
			else:
				id_edit.text = n_id_str # Cofnięcie (złe ID)
		)
		top_hbox.add_child(id_edit)

		var rand_id_btn = Button.new()
		rand_id_btn.text = "🎲"
		rand_id_btn.tooltip_text = "Generuj losowe ID"
		rand_id_btn.pressed.connect(func():
			id_edit.text = "node_" + str(Time.get_ticks_msec()).substr(3, 5)
			id_edit.release_focus() # Wymusza zapis poprzez sygnał focus_exited
		)
		top_hbox.add_child(rand_id_btn)
		
		if not is_start:
			var set_start_btn = Button.new()
			set_start_btn.text = "⭐"
			set_start_btn.tooltip_text = "Ustaw jako START"
			set_start_btn.pressed.connect(func():
				graph.set("start_node_id", StringName(n_id_str))
				ResourceSaver.save(graph, current_file_path)
				_on_refresh_pressed()
			)
			top_hbox.add_child(set_start_btn)
			
		var del_btn = Button.new()
		del_btn.text = "❌"
		del_btn.flat = true
		del_btn.modulate = Color(1.0, 0.4, 0.4)
		del_btn.pressed.connect(func():
			_on_delete_nodes_request([StringName(g_node.name)])
		)
		top_hbox.add_child(del_btn)
			
		g_node.add_child(top_hbox)
		g_node.set_slot(child_idx, true, 0, Color.WHITE, false, 0, Color.WHITE) # WEJŚCIE
		child_idx += 1

		# --- SLOT 1: GŁOŚNIK (Zarządzanie Mówcą z ograniczeniem do SpeakerData) ---
		var speaker_box = HBoxContainer.new()
		var spk_lbl = Label.new()
		spk_lbl.text = "Mówca:"
		
		var spk_picker = EditorResourcePicker.new()
		spk_picker.base_type = "SpeakerData" # <-- Kluczowa zmiana (ograniczenie listy)
		spk_picker.edited_resource = d_node.get("speaker")
		spk_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spk_picker.resource_changed.connect(func(res):
			d_node.set("speaker", res)
			ResourceSaver.save(graph, current_file_path)
		)
		speaker_box.add_child(spk_lbl)
		speaker_box.add_child(spk_picker)
		
		g_node.add_child(speaker_box)
		g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1

		# --- SLOT 2: POLE TEKSTOWE ---
		var text_edit = TextEdit.new()
		text_edit.text = str(d_node.get("dialogue_text"))
		text_edit.custom_minimum_size = Vector2(320, 80)
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		
		text_edit.focus_entered.connect(func(): _is_typing = true)
		text_edit.focus_exited.connect(func():
			_is_typing = false
			if str(d_node.get("dialogue_text")) != text_edit.text:
				d_node.set("dialogue_text", text_edit.text)
				ResourceSaver.save(graph, current_file_path)
				_on_refresh_pressed()
		)

		if text_edit.text.strip_edges() == "":
			text_edit.placeholder_text = "[WĘZEŁ LOGICZNY / ROUTER - BRAK TEKSTU]"
			g_node.self_modulate = Color(0.6, 0.8, 1.0) 

		g_node.add_child(text_edit)
		g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1
		
		# --- SLOT 3: PARAMETRY MIN. SKIP I CANCEL ---
		var params_box = HBoxContainer.new()
		var skip_lbl = Label.new()
		skip_lbl.text = "Min. Skip:"
		skip_lbl.modulate = Color.GRAY
		var skip_spin = SpinBox.new()
		skip_spin.step = 0.1
		skip_spin.max_value = 10.0
		var current_skip = d_node.get("min_skip_time")
		skip_spin.value = current_skip if current_skip != null else 0.5
		skip_spin.value_changed.connect(func(val):
			d_node.set("min_skip_time", val)
			ResourceSaver.save(graph, current_file_path)
		)
		
		var cancel_cb = CheckBox.new()
		cancel_cb.text = "Opuść Dialog (Cancel)"
		cancel_cb.modulate = Color.GRAY
		cancel_cb.button_pressed = d_node.get("allow_cancel") if d_node.get("allow_cancel") != null else false
		cancel_cb.toggled.connect(func(pressed):
			d_node.set("allow_cancel", pressed)
			ResourceSaver.save(graph, current_file_path)
			_on_refresh_pressed() # Odśwież, by zaktualizować informację o anulowaniu na dole
		)
		
		params_box.add_child(skip_lbl)
		params_box.add_child(skip_spin)
		params_box.add_child(cancel_cb)
		g_node.add_child(params_box)
		g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		child_idx += 1

		# --- SLOTY 4+: PORTY WYJŚCIOWE I EDYCJA NAZW WYBORÓW ---
		var outputs = d_node.get("outputs")
		if outputs and typeof(outputs) == TYPE_ARRAY:
			for conn in outputs:
				if conn == null: continue
				
				var out_hbox = HBoxContainer.new()
				var port_color = Color.CYAN 
				
				var conn_text_edit = LineEdit.new()
				var conn_text = str(conn.get("text"))
				conn_text_edit.text = conn_text
				conn_text_edit.placeholder_text = "▶ Auto-Przejście"
				conn_text_edit.expand_to_text_length = true
				conn_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var target = str(conn.get("target_id")).strip_edges()
				var is_dead_end = (target == "" or not nodes_dict.has(StringName(target)))
				
				if conn_text != "":
					conn_text_edit.modulate = Color.YELLOW
					port_color = Color.YELLOW
				else:
					conn_text_edit.modulate = Color.CYAN
				if is_dead_end:
					conn_text_edit.modulate = Color.RED
					port_color = Color.RED

				conn_text_edit.focus_entered.connect(func(): _is_typing = true)
				conn_text_edit.focus_exited.connect(func():
					_is_typing = false
					if conn.get("text") != conn_text_edit.text:
						conn.set("text", conn_text_edit.text)
						ResourceSaver.save(graph, current_file_path)
						_on_refresh_pressed()
				)
				
				var inspect_btn = Button.new()
				var c_size = conn.get("conditions").size() if conn.get("conditions") else 0
				var e_size = conn.get("consequences").size() if conn.get("consequences") else 0
				inspect_btn.text = "[C:%d|E:%d]" % [c_size, e_size]
				
				if c_size > 0 or e_size > 0:
					inspect_btn.modulate = Color(1.0, 0.6, 0.2)
					port_color = Color(1.0, 0.6, 0.2)
				else:
					inspect_btn.modulate = Color.GRAY
				
				inspect_btn.pressed.connect(func(): EditorInterface.edit_resource(conn))
				
				var del_conn_btn = Button.new()
				del_conn_btn.text = "x"
				del_conn_btn.modulate = Color.RED
				del_conn_btn.pressed.connect(func():
					outputs.erase(conn)
					ResourceSaver.save(graph, current_file_path)
					_on_refresh_pressed()
				)

				out_hbox.add_child(conn_text_edit)
				out_hbox.add_child(inspect_btn)
				out_hbox.add_child(del_conn_btn)

				g_node.add_child(out_hbox)
				g_node.set_slot(child_idx, false, 0, Color.WHITE, true, 0, port_color) # WYJŚCIE
				child_idx += 1

		# --- OSTATNI SLOT: PRZYCISK DODAWANIA WYJŚĆ ORAZ OPCJA CANCEL ---
		var bottom_hbox = HBoxContainer.new()
		
		var add_out_btn = Button.new()
		add_out_btn.text = "➕ Dodaj Wyjście"
		add_out_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_out_btn.pressed.connect(func():
			if outputs != null:
				outputs.append(load("res://assets/dialogue_system/resources/dialogue_connection.gd").new())
				ResourceSaver.save(graph, current_file_path)
				_on_refresh_pressed()
		)
		bottom_hbox.add_child(add_out_btn)
		
		if d_node.get("allow_cancel"):
			var cancel_lbl = Label.new()
			cancel_lbl.text = " ❌ Opuść dialog "
			cancel_lbl.modulate = Color(1.0, 0.4, 0.4)
			cancel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			bottom_hbox.add_child(cancel_lbl)
			g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.RED)
		else:
			g_node.set_slot(child_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)

		g_node.add_child(bottom_hbox)
		child_idx += 1

		add_child(g_node)

	# ETAP 2: Łączenie krawędzi
	for node_id in nodes_dict:
		var d_node = nodes_dict[node_id]
		if not d_node: continue
		var outputs = d_node.get("outputs")
		if outputs and typeof(outputs) == TYPE_ARRAY:
			for i in range(outputs.size()):
				var conn = outputs[i]
				if conn == null: continue
				var target_id_str = str(conn.get("target_id"))
				if target_id_str != "" and nodes_dict.has(StringName(target_id_str)):
					var from_name = str(node_id) + "_" + str(render_generation)
					var to_name = target_id_str + "_" + str(render_generation)
					connect_node(from_name, i, to_name, 0)

	_load_layout()

func _on_edit_graph_pressed() -> void:
	if _resource_to_render:
		EditorInterface.edit_resource(_resource_to_render)

# --- POTĘŻNE UŁATWIENIA EDYCJI ---

func _on_popup_request(pos: Vector2) -> void:
	if not _resource_to_render or current_file_path == "": return
	context_menu.set_item_disabled(1, _clipboard_nodes.is_empty()) # Blokuj "Wklej" jeśli pusty schowek
	context_menu.position = get_screen_position() + pos
	context_menu.popup()

func _on_context_menu_pressed(id: int) -> void:
	var local_pos = (get_local_mouse_position() + scroll_offset) / zoom
	if id == 0:
		_add_new_node(local_pos)
	elif id == 1:
		_paste_nodes_at(local_pos)

func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	if not _resource_to_render or current_file_path == "": return
	var local_pos = (release_position + scroll_offset) / zoom
	var new_node_id = _add_new_node(local_pos)
	_on_connection_request(from_node, from_port, StringName(new_node_id + "_" + str(render_generation)), 0)
	_on_refresh_pressed()

func _add_new_node(spawn_pos: Vector2) -> StringName:
	var graph: DialogueGraph = _resource_to_render
	var new_id = StringName("node_" + str(Time.get_ticks_msec()).substr(3, 5))
	var new_node = load("res://assets/dialogue_system/resources/dialogue_node.gd").new()
	new_node.set("id", new_id)
	new_node.set("outputs", [load("res://assets/dialogue_system/resources/dialogue_connection.gd").new()]) 
	
	var nodes_dict = graph.get("nodes")
	nodes_dict[new_id] = new_node
	if str(graph.get("start_node_id")) == &"" or nodes_dict.size() == 1:
		graph.set("start_node_id", new_id)
		
	_pending_node_positions[str(new_id)] = spawn_pos
	ResourceSaver.save(graph, current_file_path)
	_on_refresh_pressed()
	return new_id

# --- KOPIOWANIE, WKLEJANIE I DUPLIKACJA ---

func _on_copy_nodes_request() -> void:
	if not _resource_to_render: return
	_clipboard_nodes.clear()
	var nodes_dict = _resource_to_render.get("nodes")
	for child in get_children():
		if child is GraphNode and child.selected:
			var base_id = child.get_meta("base_name")
			if nodes_dict.has(StringName(base_id)):
				_clipboard_nodes.append(nodes_dict[base_id].duplicate(true))

func _on_paste_nodes_request() -> void:
	var mouse_pos = (get_local_mouse_position() + scroll_offset) / zoom
	_paste_nodes_at(mouse_pos)

func _paste_nodes_at(pos: Vector2) -> void:
	if not _resource_to_render or _clipboard_nodes.is_empty(): return
	var graph = _resource_to_render
	var nodes_dict = graph.get("nodes")
	
	for i in range(_clipboard_nodes.size()):
		var copied_node = _clipboard_nodes[i].duplicate(true)
		var new_id = StringName("node_" + str(Time.get_ticks_msec() + i).substr(3, 5))
		copied_node.set("id", new_id)
		nodes_dict[new_id] = copied_node
		_pending_node_positions[str(new_id)] = pos + Vector2(i * 50, i * 50)
		
	ResourceSaver.save(graph, current_file_path)
	_on_refresh_pressed()

func _on_duplicate_nodes_request() -> void:
	_on_copy_nodes_request()
	_on_paste_nodes_request()

# --- ZARZĄDZANIE KABLAMI ---

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_gnode = get_node_or_null(str(from_node))
	var to_gnode = get_node_or_null(str(to_node))
	if not from_gnode or not to_gnode or not _resource_to_render: return

	var from_id = from_gnode.get_meta("base_name")
	var to_id = to_gnode.get_meta("base_name")
	var d_node = _resource_to_render.get("nodes").get(StringName(from_id))
	
	if d_node:
		var outputs = d_node.get("outputs")
		if from_port < outputs.size():
			var conn = outputs[from_port]
			if conn:
				conn.set("target_id", StringName(to_id))
				connect_node(from_node, from_port, to_node, to_port)
				ResourceSaver.save(_resource_to_render, current_file_path)
				_on_refresh_pressed() 

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_gnode = get_node_or_null(str(from_node))
	if not from_gnode or not _resource_to_render: return

	var from_id = from_gnode.get_meta("base_name")
	var d_node = _resource_to_render.get("nodes").get(StringName(from_id))
	
	if d_node:
		var outputs = d_node.get("outputs")
		if from_port < outputs.size():
			var conn = outputs[from_port]
			if conn:
				conn.set("target_id", &"")
				disconnect_node(from_node, from_port, to_node, to_port)
				ResourceSaver.save(_resource_to_render, current_file_path)
				_on_refresh_pressed() 

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if not _resource_to_render: return
		
	var graph = _resource_to_render
	var nodes_dict = graph.get("nodes")
	var changed = false
	
	for n in nodes:
		var gnode = get_node_or_null(str(n))
		if gnode and gnode.has_meta("base_name"):
			var base_id = StringName(gnode.get_meta("base_name"))
			if nodes_dict.has(base_id):
				nodes_dict.erase(base_id)
				changed = true
				
			for other_id in nodes_dict:
				var other_node = nodes_dict[other_id]
				var outputs = other_node.get("outputs")
				if outputs:
					for conn in outputs:
						if conn != null and conn.get("target_id") == base_id:
							conn.set("target_id", &"")

	if changed:
		ResourceSaver.save(graph, current_file_path)
		_on_refresh_pressed()

# --- SYSTEM LAYOUTU ---
func _save_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	var layout_data = {}
	for child in get_children():
		if child is GraphNode and child.has_meta("base_name"):
			layout_data[child.get_meta("base_name")] = {
				"pos_x": child.position_offset.x,
				"pos_y": child.position_offset.y,
				"size_x": child.size.x,
				"size_y": child.size.y
			}
	var file = FileAccess.open(layout_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(layout_data))

func _load_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	
	var layout_data = {}
	if FileAccess.file_exists(layout_path):
		var file = FileAccess.open(layout_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			layout_data = json.data
			
	for child in get_children():
		if child is GraphNode and child.has_meta("base_name"):
			var b_name = child.get_meta("base_name")
			
			if layout_data.has(b_name):
				var d = layout_data[b_name]
				child.position_offset = Vector2(d["pos_x"], d["pos_y"])
				child.size = Vector2(d["size_x"], d["size_y"])
			elif _pending_node_positions.has(b_name):
				child.position_offset = _pending_node_positions[b_name]
				_pending_node_positions.erase(b_name)

func _reset_layout() -> void:
	if current_file_path == "": return
	var layout_path = current_file_path + ".layout"
	if FileAccess.file_exists(layout_path):
		DirAccess.remove_absolute(layout_path)
		_on_refresh_pressed()
